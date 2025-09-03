require 'net/http'
require 'uri'
require 'nokogiri'
require 'csv'
require 'securerandom'

class ScraperController < ApplicationController
  BASE_URL = 'https://activation-service.jp/iso/column/type-9001/type-9001-beginner?type=category'

  def index
    @scrape_session_id = session[:scrape_session_id]
    @articles = @scrape_session_id ? ScrapedArticle.for_session(@scrape_session_id).order(:created_at) : []
  end

  def scrape
    begin
      # 新しいスクレイピングセッションを開始
      scrape_session_id = SecureRandom.uuid
      session[:scrape_session_id] = scrape_session_id
      
      # 既存のデータを削除（同じセッション）
      ScrapedArticle.for_session(scrape_session_id).delete_all
      
      articles_data = scrape_all_pages
      
      # データベースに保存
      articles_data.each do |article_data|
        ScrapedArticle.create!(
          title: article_data[:title],
          link: article_data[:link],
          date: article_data[:date],
          scrape_session_id: scrape_session_id
        )
      end
      
      flash[:notice] = "#{articles_data.length}件の記事を取得しました。"
      redirect_to root_path
    rescue => e
      Rails.logger.error "Scraping error: #{e.message}"
      flash[:alert] = "エラーが発生しました: #{e.message}"
      redirect_to root_path
    end
  end

  def download_csv
    @scrape_session_id = session[:scrape_session_id]
    @articles = @scrape_session_id ? ScrapedArticle.for_session(@scrape_session_id).order(:created_at) : []
    
    respond_to do |format|
      format.csv do
        csv_data = generate_csv(@articles)
        send_data csv_data, 
                  filename: "iso9001_articles_#{Date.current.strftime('%Y%m%d')}.csv",
                  type: 'text/csv'
      end
    end
  end

  def generate_pdf
    begin
      @scrape_session_id = session[:scrape_session_id]
      @articles = @scrape_session_id ? ScrapedArticle.for_session(@scrape_session_id).order(:created_at) : []
      
      if @articles.empty?
        flash[:alert] = "PDF生成用のデータがありません。まず記事をスクレイピングしてください。"
        redirect_to root_path
        return
      end
      
      # 各記事のURLをPDF化してZIPファイルとしてダウンロード
      zip_content = generate_pdfs_as_zip(@articles)
      
      send_data zip_content,
                filename: "iso9001_articles_pdfs_#{Date.current.strftime('%Y%m%d')}.zip",
                type: 'application/zip',
                disposition: 'attachment'
      
    rescue => e
      Rails.logger.error "PDF generation error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      flash[:alert] = "PDF生成中にエラーが発生しました: #{e.message}"
      redirect_to root_path
    end
  end

  private

  def scrape_article_content(article_url)
    begin
      uri = URI(article_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.read_timeout = 30
      http.open_timeout = 30
      
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
      
      response = http.request(request)
      return nil unless response.code == '200'
      
      doc = Nokogiri::HTML(response.body)
      
      # 記事のメインコンテンツを抽出
      content_selectors = [
        '.single-content',
        '.entry-content',
        '.post-content',
        '.article-content',
        '.content',
        'main .content',
        '[class*="content"]'
      ]
      
      content_element = nil
      content_selectors.each do |selector|
        content_element = doc.css(selector).first
        break if content_element
      end
      
      return nil unless content_element
      
      # 不要な要素を除去
      content_element.css('script, style, .advertisement, .ads, .social-share, .related-posts, .comments').remove
      
      # 画像のaltタグをテキストに変換（PDFでの表示用）
      content_element.css('img').each do |img|
        alt_text = img['alt']
        if alt_text.present?
          img.replace("[画像: #{alt_text}]")
        else
          img.remove
        end
      end
      
      # HTMLをクリーンアップ
      cleaned_html = content_element.to_html
      
      # 不要なクラスやスタイルを除去
      cleaned_html = cleaned_html.gsub(/\s+class="[^"]*"/, '')
      cleaned_html = cleaned_html.gsub(/\s+style="[^"]*"/, '')
      cleaned_html = cleaned_html.gsub(/\s+id="[^"]*"/, '')
      
      cleaned_html
      
    rescue => e
      Rails.logger.error "Content scraping error for #{article_url}: #{e.message}"
      nil
    end
  end

  def strip_html_tags(html_string)
    return '' if html_string.blank?
    
    # NokogiriでHTMLをパースしてテキストだけを抽出
    doc = Nokogiri::HTML(html_string)
    text = doc.text
    
    # 改行を整理
    text = text.gsub(/\n\s*\n/, "\n\n") # 連続する空行を一つに
    text = text.gsub(/\s+/, ' ') # 連続するスペースを一つに
    text.strip
  end

  def generate_pdfs_as_zip(articles)
    require 'zip'
    require 'tempfile'
    
    # 一時ファイルを作成
    temp_zip = Tempfile.new(['articles', '.zip'])
    
    begin
      Zip::File.open(temp_zip.path, create: true) do |zipfile|
        articles.each_with_index do |article, index|
          Rails.logger.info "Generating content for article #{index + 1}/#{articles.length}: #{article.title}"
          
          begin
            content = generate_single_pdf(article.link)
            
            if content
              # ファイル名を安全な文字に変換
              safe_filename = sanitize_filename("#{index + 1}_#{article.title}")
              
              # 印刷用にHTMLファイルとして保存（ブラウザーでPDF化可能）
              filename = "#{safe_filename}.html"
              
              zipfile.get_output_stream(filename) { |f| f.write(content) }
            else
              Rails.logger.warn "Failed to generate content for: #{article.link}"
              # エラーファイルを作成
              error_content = "コンテンツ生成に失敗しました\n\nタイトル: #{article.title}\nURL: #{article.link}\n日付: #{article.date || '日付不明'}"
              safe_filename = sanitize_filename("#{index + 1}_#{article.title}_ERROR")
              zipfile.get_output_stream("#{safe_filename}.txt") { |f| f.write(error_content) }
            end
          rescue => e
            Rails.logger.error "Error generating content for #{article.link}: #{e.message}"
            # エラーファイルを作成
            error_content = "コンテンツ生成エラー\n\nタイトル: #{article.title}\nURL: #{article.link}\n日付: #{article.date || '日付不明'}\n\nエラー: #{e.message}"
            safe_filename = sanitize_filename("#{index + 1}_#{article.title}_ERROR")
            zipfile.get_output_stream("#{safe_filename}.txt") { |f| f.write(error_content) }
          end
          
          # サーバーへの負荷を軽減
          sleep 2
        end
      end
      
      # ZIPファイルの内容を読み取り
      File.read(temp_zip.path)
    ensure
      temp_zip.close
      temp_zip.unlink
    end
  end

  def generate_single_pdf(url)
    begin
      Rails.logger.info "Starting content generation for: #{url}"
      
      # URLのコンテンツを取得
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.read_timeout = 30
      http.open_timeout = 30
      
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
      
      response = http.request(request)
      Rails.logger.info "HTTP response code: #{response.code}"
      
      unless response.code == '200'
        Rails.logger.error "HTTP request failed with code: #{response.code}"
        return generate_fallback_html(url)
      end
      
      # HTMLコンテンツを処理してメインコンテンツのみを抽出
      doc = Nokogiri::HTML(response.body)
      
      # メインコンテンツを抽出
      main_content = extract_main_content(doc)
      
      # PDF印刷に最適化されたHTMLテンプレートを作成
      print_ready_html = create_print_ready_html(main_content, url)
      
      Rails.logger.info "Generated print-ready HTML content (#{print_ready_html.bytesize} bytes)"
      
      return print_ready_html
      
    rescue => e
      Rails.logger.error "Content generation error for #{url}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # フォールバック: シンプルなHTMLコンテンツを返す
      return generate_fallback_html(url)
    end
  end

  def generate_fallback_html(url)
    begin
      # URLのコンテンツを取得
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.read_timeout = 30
      http.open_timeout = 30
      
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
      
      response = http.request(request)
      return nil unless response.code == '200'
      
      doc = Nokogiri::HTML(response.body)
      
      # メインコンテンツを抽出
      main_content = extract_main_content(doc)
      
      # クリーンなHTMLテンプレートを作成
      create_clean_html(main_content, url)
      
    rescue => e
      Rails.logger.error "Fallback HTML generation error for #{url}: #{e.message}"
      nil
    end
  end

  def extract_main_content(doc)
    # 不要な要素を除去
    doc.css('script, style, header, nav, footer, .header, .footer, .sidebar, .navigation, .nav, .navbar, .menu, .breadcrumb, .social-share, .ads, .advertisement, .banner, .popup, .modal, .overlay, .cookie-notice, .related-posts, .comments, .comment-section, .author-box, .pagination, .page-navigation, .share-buttons, .social-buttons').remove
    
    # メインコンテンツを探す
    main_selectors = [
      'main', '.main', '.content', '.main-content', '.article-content',
      '.post-content', '.entry-content', '.page-content', '.single-content',
      'article', '.article', '.post', '.entry', '.page'
    ]
    
    main_content = nil
    main_selectors.each do |selector|
      element = doc.css(selector).first
      if element && element.text.strip.length > 100
        main_content = element
        break
      end
    end
    
    # メインコンテンツが見つからない場合はbodyを使用
    main_content ||= doc.css('body').first
    
    main_content
  end

  def create_print_ready_html(content, url)
    title = content.css('h1, h2, .title').first&.text&.strip || url
    
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>#{title}</title>
        <style>
          /* ベーススタイル */
          * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
          }
          
          body {
            font-family: 'Hiragino Sans', 'Hiragino Kaku Gothic ProN', 'Yu Gothic UI', 'Meiryo', sans-serif;
            font-size: 14px;
            line-height: 1.6;
            color: #333;
            background: white;
            margin: 0;
            padding: 20px;
          }
          
          /* ヘッダースタイル */
          h1, h2, h3, h4, h5, h6 {
            color: #2c3e50;
            margin-top: 24px;
            margin-bottom: 12px;
            font-weight: 600;
            page-break-after: avoid;
          }
          
          h1 { 
            font-size: 28px; 
            border-bottom: 3px solid #3498db;
            padding-bottom: 8px;
          }
          h2 { 
            font-size: 22px; 
            border-left: 4px solid #3498db;
            padding-left: 12px;
          }
          h3 { font-size: 18px; }
          h4 { font-size: 16px; }
          
          /* テキストスタイル */
          p {
            margin-bottom: 14px;
            text-align: justify;
            orphans: 2;
            widows: 2;
          }
          
          /* リストスタイル */
          ul, ol {
            margin: 16px 0;
            padding-left: 25px;
          }
          
          li {
            margin-bottom: 6px;
            page-break-inside: avoid;
          }
          
          /* 画像スタイル */
          img { 
            max-width: 100%; 
            height: auto;
            margin: 15px 0;
            page-break-inside: avoid;
            display: block;
          }
          
          /* テーブルスタイル */
          table { 
            border-collapse: collapse; 
            width: 100%; 
            margin: 20px 0;
            page-break-inside: avoid;
          }
          
          th, td { 
            border: 1px solid #ddd; 
            padding: 10px; 
            text-align: left;
            font-size: 12px;
          }
          
          th { 
            background-color: #f8f9fa;
            font-weight: 600;
          }
          
          /* 引用スタイル */
          blockquote {
            border-left: 4px solid #3498db;
            margin: 20px 0;
            padding: 15px 20px;
            background: #f8f9fa;
            font-style: italic;
            page-break-inside: avoid;
          }
          
          /* コードスタイル */
          pre, code {
            background: #f4f4f4;
            padding: 12px;
            border-radius: 4px;
            font-family: 'Monaco', 'Menlo', 'Courier New', monospace;
            font-size: 12px;
            page-break-inside: avoid;
            overflow-wrap: break-word;
          }
          
          /* URL情報スタイル */
          .url-info {
            background: #e8f4fd;
            border: 1px solid #bee5eb;
            padding: 15px;
            margin-bottom: 25px;
            font-size: 12px;
            color: #0c5460;
            border-radius: 4px;
            page-break-inside: avoid;
          }
          
          /* 印刷用スタイル */
          @media print {
            body {
              font-size: 12px;
              line-height: 1.4;
              margin: 0;
              padding: 1cm;
            }
            
            * {
              -webkit-print-color-adjust: exact !important;
              color-adjust: exact !important;
            }
            
            h1, h2, h3, h4, h5, h6 {
              page-break-after: avoid;
              page-break-inside: avoid;
            }
            
            p, li {
              page-break-inside: avoid;
              orphans: 2;
              widows: 2;
            }
            
            img {
              page-break-inside: avoid;
              page-break-after: avoid;
            }
            
            table {
              page-break-inside: avoid;
            }
            
            blockquote, pre {
              page-break-inside: avoid;
            }
            
            .url-info {
              page-break-after: avoid;
            }
          }
          
          /* ブラウザー表示用のスタイル */
          @media screen {
            body {
              max-width: 210mm;
              margin: 0 auto;
              box-shadow: 0 0 10px rgba(0,0,0,0.1);
              background: white;
            }
            
            .print-instructions {
              position: fixed;
              top: 10px;
              right: 10px;
              background: #007bff;
              color: white;
              padding: 10px 15px;
              border-radius: 4px;
              font-size: 12px;
              box-shadow: 0 2px 5px rgba(0,0,0,0.2);
              z-index: 1000;
            }
          }
          
          @media print {
            .print-instructions {
              display: none;
            }
          }
        </style>
      </head>
      <body>
        <div class="print-instructions">
          ブラウザーの印刷機能でPDF化できます
        </div>
        
        <div class="url-info">
          <strong>元URL:</strong> #{url}<br>
          <strong>生成日時:</strong> #{Time.current.strftime('%Y年%m月%d日 %H:%M:%S')}<br>
          <strong>注意:</strong> このファイルはメインコンテンツのみを抽出しています。
        </div>
        
        <div class="main-content">
          #{content.inner_html}
        </div>
      </body>
      </html>
    HTML
  end



  def sanitize_filename(filename)
    # ファイル名に使用できない文字を除去/置換
    filename.gsub(/[\\\/:*?"<>|]/, '_')
            .gsub(/\s+/, '_')
            .slice(0, 100) # 最大1000文字に制限
  end

  def scrape_all_pages
    articles = []
    page_num = 1
    
    loop do
      Rails.logger.info "Scraping page #{page_num}..."
      
      url = page_num == 1 ? BASE_URL : "#{BASE_URL}&page=#{page_num}"
      page_articles = scrape_single_page(url)
      
      break if page_articles.empty?
      
      articles.concat(page_articles)
      page_num += 1
      
      # 次のページが存在するかチェック
      break unless has_next_page?(url)
      
      # サーバーへの負荷を軽減
      sleep 1
    end
    
    articles
  end

  def scrape_single_page(url)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.read_timeout = 30
    http.open_timeout = 30
    
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    request['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
    request['Accept-Language'] = 'ja,en-US;q=0.9,en;q=0.8'
    
    response = http.request(request)
    
    return [] unless response.code == '200'
    
    doc = Nokogiri::HTML(response.body)
    articles = []
    
    # メインアプローチ: popular__itemクラスの記事リンクを探す
    popular_links = doc.css('a.popular__item')
    
    popular_links.each do |link|
      href = link['href']
      next unless href
      
      # ISO9001の実際の記事リンクかどうかチェック
      next unless href.include?('iso') && href.match?(/\/\d+/)
      
      # 相対URLの場合は絶対URLに変換
      href = URI.join(url, href).to_s unless href.start_with?('http')
      
      # popular__titleからタイトルを取得
      title_element = link.css('.popular__title').first
      title = title_element&.text&.strip
      
      # popular__dateから日付を取得
      date_element = link.css('.popular__date').first
      date = nil
      if date_element
        date_text = date_element.text.strip
        date = parse_date(date_text)
      end
      
      next if title.blank? || title.length < 3
      
      articles << {
        title: title.strip,
        link: href,
        date: date
      }
    end
    
    # archive__textとarchive__titleを使ったアプローチ（ユーザー指定のクラス構造）
    if articles.empty?
      archive_texts = doc.css('.archive__text')
      
      archive_texts.each do |archive_text|
        # archive__titleからタイトルを取得
        title_element = archive_text.css('.archive__title').first || archive_text.css('p.archive__title').first
        title = title_element&.text&.strip
        
        next if title.blank? || title.length < 3
        
        # 関連するリンクを探す
        links = archive_text.css('a[href]')
        if links.empty? && archive_text.parent
          links = archive_text.parent.css('a[href]')
        end
        
        links.each do |link|
          href = link['href']
          next unless href
          
          # ISO関連のリンクのみを対象とする
          next unless href.include?('iso') || href.include?('9001') || href.include?('column')
          
          # 相対URLの場合は絶対URLに変換
          href = URI.join(url, href).to_s unless href.start_with?('http')
          
          # 日付を取得しようとする
          date = extract_date(link)
          
          articles << {
            title: title.strip,
            link: href,
            date: date
          }
        end
      end
    end
    
    # フォールバックアプローチ
    if articles.empty?
      # 複数のセレクターパターンで記事を探す
      selectors = [
        'article a[href]',
        '.post-item a[href]',
        '.article-item a[href]',
        '.column-item a[href]',
        '.content-item a[href]',
        '.news-item a[href]',
        'a[href*="iso"][href*="9001"]',
        'a[href*="column"]'
      ]
      
      selectors.each do |selector|
        links = doc.css(selector)
        links.each do |link|
          href = link['href']
          next unless href
          
          # 相対URLの場合は絶対URLに変換
          href = URI.join(url, href).to_s unless href.start_with?('http')
          
          title = extract_title(link)
          date = extract_date(link)
          
          next if title.blank? || title.length < 3
          
          articles << {
            title: title.strip,
            link: href,
            date: date
          }
        end
        
        break if articles.length > 0 # 記事が見つかったらループを終了
      end
    end
    
    # 重複を除去
    articles.uniq { |article| article[:link] }
  end

  def extract_title(element)
    # 指定されたクラス構造でタイトルを探す: div.archive__text > p.archive__title
    title = nil
    
    # リンクの親要素から .archive__text を探す
    current_element = element
    5.times do # 最大5階層上まで探す
      break unless current_element
      
      # 現在の要素または兄弟要素で .archive__text を探す
      archive_text_element = current_element.css('.archive__text').first
      archive_text_element ||= current_element.parent&.css('.archive__text')&.first if current_element.parent
      
      if archive_text_element
        # archive__text内のp.archive__titleを探す
        title_element = archive_text_element.css('p.archive__title').first
        if title_element
          title = title_element.text.strip
          break if title.present? && title.length > 3
        end
      end
      
      current_element = current_element.parent
      break if current_element&.name == 'body'
    end
    
    # 指定されたクラス構造で見つからない場合のフォールバック
    if title.blank?
      # より広い範囲でarchive__titleを探す
      doc = element.document
      title_elements = doc.css('p.archive__title')
      
      title_elements.each do |title_element|
        candidate_title = title_element.text.strip
        if candidate_title.present? && candidate_title.length > 3
          title = candidate_title
          break
        end
      end
    end
    
    # 不要な文字を除去
    title = title.gsub(/\s+/, ' ').strip if title
    title
  end

  def extract_date(element)
    # 指定されたクラス構造で日付を探す: div.headCont__date
    date = nil
    
    # リンクの親要素から .headCont__date を探す
    current_element = element
    5.times do # 最大5階層上まで探す
      break unless current_element
      
      # 現在の要素または兄弟要素で .headCont__date を探す
      date_element = current_element.css('.headCont__date').first
      date_element ||= current_element.parent&.css('.headCont__date')&.first if current_element.parent
      
      if date_element
        date_text = date_element.text.strip
        date_text = date_element['datetime'] if date_text.blank? && date_element['datetime']
        parsed_date = parse_date(date_text)
        if parsed_date
          date = parsed_date
          break
        end
      end
      
      current_element = current_element.parent
      break if current_element&.name == 'body'
    end
    
    # 指定されたクラス構造で見つからない場合のフォールバック
    if date.blank?
      # より広い範囲でheadCont__dateを探す
      doc = element.document
      date_elements = doc.css('.headCont__date')
      
      date_elements.each do |date_element|
        date_text = date_element.text.strip
        date_text = date_element['datetime'] if date_text.blank? && date_element['datetime']
        parsed_date = parse_date(date_text)
        if parsed_date
          date = parsed_date
          break
        end
      end
    end
    
    # 従来のパターンも試す（フォールバック）
    if date.blank?
      date_patterns = ['.date', '.updated', '.published', '.post-date', 'time', '.created', '.modified']
      
      current_element = element
      2.times do # 最大2階層上まで探す
        break unless current_element
        date_patterns.each do |pattern|
          date_element = current_element.css(pattern).first
          if date_element
            date_text = date_element.text.strip
            date_text = date_element['datetime'] if date_text.blank? && date_element['datetime']
            parsed_date = parse_date(date_text)
            if parsed_date
              date = parsed_date
              break
            end
          end
        end
        break if date.present?
        current_element = current_element.parent
        break if current_element&.name == 'body'
      end
    end
    
    date
  end

  def parse_date(date_string)
    return nil if date_string.blank?
    
    # 日本語の日付パターン
    if date_string.match(/\d{4}年\d{1,2}月\d{1,2}日/)
      begin
        return Date.strptime(date_string, '%Y年%m月%d日').strftime('%Y-%m-%d')
      rescue Date::Error
        # 継続
      end
    end
    
    # 様々な日付フォーマットに対応
    date_patterns = [
      '%Y/%m/%d',
      '%Y-%m-%d',
      '%m/%d/%Y',
      '%d/%m/%Y',
      '%Y.%m.%d'
    ]
    
    date_patterns.each do |pattern|
      begin
        return Date.strptime(date_string, pattern).strftime('%Y-%m-%d')
      rescue Date::Error
        next
      end
    end
    
    # ISO8601形式の場合
    begin
      return Date.parse(date_string).strftime('%Y-%m-%d')
    rescue Date::Error
      nil
    end
  end

  def has_next_page?(current_url)
    uri = URI(current_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.read_timeout = 15
    http.open_timeout = 15
    
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
    
    response = http.request(request)
    return false unless response.code == '200'
    
    doc = Nokogiri::HTML(response.body)
    
    # 次のページリンクを探す
    next_selectors = [
      'a[href*="page="]',
      '.next',
      '.pagination .next',
      'a:contains("次へ")',
      'a:contains("Next")',
      '.pager .next'
    ]
    
    next_selectors.any? do |selector|
      doc.css(selector).any?
    end
  end

  def generate_csv(articles)
    CSV.generate(encoding: 'UTF-8') do |csv|
      csv << ['タイトル', 'リンク', '日付']
      
      articles.each do |article|
        csv << [
          article.title,
          article.link,
          article.date || '日付不明'
        ]
      end
    end
  end
end
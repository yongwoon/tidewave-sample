#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'ferrum'
require 'fileutils'

class WorkingPDFScraper
  def initialize(url = 'https://activation-service.jp/iso/column/8334', filename = 'construction_permit_article')
    @url = url
    @pdf_filename = "#{filename}.pdf"
    @browser = nil
  end

  def generate_pdf
    puts "🚀 PDF 생성을 시작합니다..."
    puts "📄 URL: #{@url}"
    puts "💾 출력 파일: #{@pdf_filename}"
    puts "=" * 50

    setup_browser
    load_and_clean_page
    create_pdf_with_working_options

    puts "\n🎉 처리 완료!"

  rescue => e
    puts "❌ 오류 발생: #{e.message}"
    puts "상세:"
    puts e.backtrace[0..2].join("\n")
  ensure
    @browser&.quit
  end

  private

  def setup_browser
    puts "🔧 브라우저 시작 중..."

    @browser = Ferrum::Browser.new(
      headless: true,
      window_size: [1200, 1000],
      browser_options: {
        'no-sandbox' => nil,
        'disable-dev-shm-usage' => nil,
        'disable-web-security' => nil
      },
      timeout: 60
    )

    puts "✅ 브라우저 시작 완료"
  end

  def load_and_clean_page
    puts "📥 페이지 로딩 중..."

    @browser.goto(@url)
    @browser.network.wait_for_idle(duration: 3)

    puts "🧹 페이지 정리 중..."

    # JavaScript로 페이지 정리 및 스타일링
    @browser.execute(<<~JAVASCRIPT)
      (function() {
        console.log('페이지 정리 시작...');

        // 1. 불필요한 요소 제거
        const elementsToRemove = [
          'header', 'nav', 'footer',
          '.header', '.nav', '.footer',
          '.site-header', '.site-footer', '.site-nav',
          '.navbar', '.navigation', '.nav-menu',
          '.sidebar', '.side-menu', '.sidebar-menu',
          '.breadcrumb', '.breadcrumbs',
          '.social-share', '.share-buttons', '.social-buttons',
          '.related-posts', '.related-articles', '.related-content',
          '.comments', '.comment-section', '.comment-form',
          '.advertisement', '.ad', '.ads', '.ad-banner',
          '[class*="ad-"]', '[id*="ad-"]',
          '.popup', '.modal', '.overlay', '.lightbox',
          '.cookie-notice', '.cookie-banner', '.cookie-consent',
          '.back-to-top', '.scroll-to-top',
          '.newsletter-signup', '.subscription-box'
        ];

        let removedCount = 0;
        elementsToRemove.forEach(selector => {
          try {
            const elements = document.querySelectorAll(selector);
            elements.forEach(el => {
              el.remove();
              removedCount++;
            });
          } catch (e) {
            // 선택자 오류는 무시
          }
        });

        console.log(`${removedCount}개 요소 제거 완료`);

        // 2. 메인 콘텐츠 찾기 및 스타일링
        const main = document.querySelector('main') ||
                     document.querySelector('article') ||
                     document.querySelector('.main-content') ||
                     document.querySelector('.content');

        // 3. 전체 페이지 스타일 추가
        const style = document.createElement('style');
        style.innerHTML = `
          * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
          }

          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
                         "Helvetica Neue", Arial, "Noto Sans", sans-serif,
                         "Hiragino Sans", "Hiragino Kaku Gothic ProN", Meiryo !important;
            font-size: 16px !important;
            line-height: 1.7 !important;
            color: #333 !important;
            background: white !important;
            padding: 40px !important;
            max-width: 800px !important;
            margin: 0 auto !important;
          }

          h1, h2, h3, h4, h5, h6 {
            font-weight: bold !important;
            color: #2c3e50 !important;
            margin-top: 2em !important;
            margin-bottom: 1em !important;
            line-height: 1.4 !important;
          }

          h1 {
            font-size: 2em !important;
            border-bottom: 3px solid #3498db !important;
            padding-bottom: 0.5em !important;
            margin-bottom: 1.5em !important;
          }

          h2 {
            font-size: 1.5em !important;
            border-left: 5px solid #3498db !important;
            padding-left: 15px !important;
          }

          h3 {
            font-size: 1.25em !important;
            color: #34495e !important;
          }

          p {
            margin: 1em 0 !important;
            text-align: justify !important;
          }

          ul, ol {
            margin: 1em 0 !important;
            padding-left: 2em !important;
          }

          li {
            margin: 0.5em 0 !important;
            line-height: 1.6 !important;
          }

          img {
            max-width: 100% !important;
            height: auto !important;
            margin: 20px 0 !important;
            display: block !important;
            box-shadow: 0 4px 8px rgba(0,0,0,0.1) !important;
            border-radius: 8px !important;
          }

          table {
            width: 100% !important;
            border-collapse: collapse !important;
            margin: 20px 0 !important;
          }

          th, td {
            border: 1px solid #ddd !important;
            padding: 12px !important;
            text-align: left !important;
          }

          th {
            background-color: #f8f9fa !important;
            font-weight: bold !important;
          }
        `;

        document.head.appendChild(style);

        // 4. body 배경색 강제 설정
        document.body.style.setProperty('background-color', 'white', 'important');
        document.body.style.setProperty('color', '#333', 'important');

        console.log('페이지 스타일링 완료');

        return 'success';
      })();
    JAVASCRIPT

    # 스타일 적용 대기
    sleep(2)
    puts "✅ 페이지 정리 완료"
  end

  def create_pdf_with_working_options
    puts "📄 PDF 생성 중..."

    # 디버그에서 확인된 기본 방법 사용 (옵션 없이)
    begin
      @browser.pdf(path: @pdf_filename)

      if File.exist?(@pdf_filename)
        file_size = File.size(@pdf_filename)
        puts "✅ PDF 생성 성공!"
        puts "📄 파일명: #{@pdf_filename}"
        puts "📦 파일 크기: #{(file_size / 1024.0 / 1024.0).round(2)} MB"

        # 파일 크기가 너무 작으면 경고
        if file_size < 10000
          puts "⚠️  파일 크기가 작습니다. 내용이 제대로 포함되었는지 확인하세요."
        end

      else
        puts "❌ PDF 파일이 생성되지 않았습니다."
        create_html_fallback
      end

    rescue => e
      puts "❌ PDF 생성 실패: #{e.message}"
      create_html_fallback
    end
  end

  def create_html_fallback
    puts "\n📝 HTML 대체 파일 생성 중..."

    html_filename = @pdf_filename.gsub('.pdf', '.html')

    begin
      # 현재 페이지의 HTML 가져오기
      page_html = @browser.body

      # 완전한 HTML 문서 생성
      complete_html = <<~HTML
        <!DOCTYPE html>
        <html lang="ko">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>건설업 허가가 필요한 공사·불요한 공사</title>
          <style>
            @media print {
              body {
                font-size: 12pt !important;
                line-height: 1.5 !important;
                padding: 0 !important;
                margin: 1cm !important;
              }
              h1 { font-size: 18pt !important; }
              h2 { font-size: 16pt !important; }
              h3 { font-size: 14pt !important; }
              @page { margin: 2cm; size: A4; }
            }
          </style>
        </head>
        <body>
        #{page_html}
        </body>
        </html>
      HTML

      File.write(html_filename, complete_html, encoding: 'utf-8')

      file_size = File.size(html_filename)
      puts "✅ HTML 파일 생성 완료!"
      puts "📄 파일명: #{html_filename}"
      puts "📦 파일 크기: #{(file_size / 1024.0).round(2)} KB"

      puts "\n📋 수동 PDF 변환 방법:"
      puts "1. 생성된 HTML 파일을 브라우저에서 열기:"
      puts "   open #{html_filename}"
      puts ""
      puts "2. 브라우저에서 인쇄 실행:"
      puts "   • macOS: Cmd+P"
      puts "   • Windows/Linux: Ctrl+P"
      puts ""
      puts "3. 인쇄 설정:"
      puts "   • 대상: 'PDF로 저장' 선택"
      puts "   • 용지 크기: A4"
      puts "   • 여백: 기본값"
      puts "   • 옵션: '배경 그래픽' 체크"
      puts ""
      puts "4. 저장하여 PDF 생성 완료"

    rescue => e
      puts "❌ HTML 파일 생성도 실패: #{e.message}"
    end
  end
end

# 명령행 인수 처리
def parse_args
  case ARGV.length
  when 0
    ['https://activation-service.jp/iso/column/8334', 'construction_permit_article']
  when 1
    [ARGV[0], 'webpage_content']
  when 2
    [ARGV[0], ARGV[1]]
  else
    puts "사용법: ruby #{$0} [URL] [파일명]"
    exit 1
  end
end

# 실행
if __FILE__ == $0
  if ARGV.include?('--help') || ARGV.include?('-h')
    puts <<~HELP
      사용법:
        ruby #{$0}                     # 기본 URL 사용
        ruby #{$0} <URL>               # URL 지정
        ruby #{$0} <URL> <파일명>       # URL과 파일명 지정

      예시:
        ruby #{$0}
        ruby #{$0} https://example.com
        ruby #{$0} https://example.com my_article
    HELP
    exit 0
  end

  begin
    url, filename = parse_args

    puts "🌐 웹페이지 → PDF 변환 도구"
    puts "📅 #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"

    scraper = WorkingPDFScraper.new(url, filename)
    scraper.generate_pdf

  rescue Interrupt
    puts "\n\n⚠️ 사용자에 의해 중단되었습니다"
  rescue => e
    puts "\n❌ 예상치 못한 오류: #{e.message}"
    puts e.backtrace[0..2].join("\n")
  end
end

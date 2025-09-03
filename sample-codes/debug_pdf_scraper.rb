#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'ferrum'

class DebugPDFGenerator
  def initialize(url = 'https://activation-service.jp/iso/column/8334')
    @url = url
    @browser = nil
  end

  def debug_and_generate
    puts "🔍 PDF 생성 디버깅을 시작합니다..."
    puts "=" * 50
    
    # 1. 시스템 환경 확인
    check_system_environment
    
    # 2. Chrome 경로 확인
    check_chrome_installation
    
    # 3. 브라우저 시작 테스트
    test_browser_startup
    
    # 4. 페이지 로드 테스트
    test_page_loading
    
    # 5. PDF 생성 테스트 (다양한 방법)
    test_pdf_generation_methods
    
  rescue => e
    puts "❌ 오류 발생: #{e.message}"
    puts "스택 트레이스:"
    puts e.backtrace[0..3].join("\n")
  ensure
    @browser&.quit
  end

  private

  def check_system_environment
    puts "\n🖥️  시스템 환경 체크:"
    puts "Ruby 버전: #{RUBY_VERSION}"
    puts "플랫폼: #{RUBY_PLATFORM}"
    puts "Ferrum 버전: #{Ferrum::VERSION}" rescue puts "Ferrum 버전: 확인 불가"
    puts "현재 디렉토리: #{Dir.pwd}"
    puts "쓰기 권한: #{File.writable?(Dir.pwd) ? '✅' : '❌'}"
  end

  def check_chrome_installation
    puts "\n🌐 Chrome/Chromium 설치 확인:"
    
    possible_paths = [
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',  # macOS
      '/Applications/Chromium.app/Contents/MacOS/Chromium',           # macOS Chromium
      '/usr/bin/google-chrome',                                       # Linux
      '/usr/bin/google-chrome-stable',                               # Linux
      '/usr/bin/chromium-browser',                                    # Linux Chromium
      '/snap/bin/chromium',                                           # Linux Snap
    ]
    
    found_chrome = false
    possible_paths.each do |path|
      if File.exist?(path)
        puts "✅ 발견: #{path}"
        found_chrome = true
        
        # 버전 확인 시도
        begin
          version = `"#{path}" --version 2>/dev/null`.strip
          puts "   버전: #{version}"
        rescue
          puts "   버전: 확인 불가"
        end
      end
    end
    
    unless found_chrome
      puts "❌ Chrome/Chromium을 찾을 수 없습니다!"
      puts "💡 해결방법:"
      puts "   macOS: brew install --cask google-chrome"
      puts "   Ubuntu: sudo apt install google-chrome-stable"
      return false
    end
    
    true
  end

  def test_browser_startup
    puts "\n🚀 브라우저 시작 테스트:"
    
    begin
      @browser = Ferrum::Browser.new(
        headless: true,
        window_size: [1200, 800],
        browser_options: {
          'no-sandbox' => nil,
          'disable-dev-shm-usage' => nil,
          'disable-web-security' => nil
        },
        timeout: 30
      )
      puts "✅ 브라우저 시작 성공"
      
      # 버전 정보 가져오기
      version = @browser.evaluate('navigator.userAgent')
      puts "   User Agent: #{version[0..80]}..."
      
      return true
    rescue => e
      puts "❌ 브라우저 시작 실패: #{e.message}"
      return false
    end
  end

  def test_page_loading
    puts "\n📥 페이지 로딩 테스트:"
    
    begin
      puts "페이지 접속 중: #{@url}"
      @browser.goto(@url)
      @browser.network.wait_for_idle(duration: 2)
      
      title = @browser.evaluate('document.title')
      puts "✅ 페이지 로드 성공"
      puts "   제목: #{title}"
      
      # 페이지 크기 확인
      body_length = @browser.evaluate('document.body.innerHTML.length')
      puts "   본문 크기: #{body_length} 문자"
      
      return true
    rescue => e
      puts "❌ 페이지 로딩 실패: #{e.message}"
      return false
    end
  end

  def test_pdf_generation_methods
    puts "\n📄 PDF 생성 방법 테스트:"
    
    # 방법 1: 기본 PDF 생성
    test_basic_pdf_generation
    
    # 방법 2: 상세 옵션으로 PDF 생성
    test_detailed_pdf_generation
    
    # 방법 3: 최소 옵션으로 PDF 생성
    test_minimal_pdf_generation
  end

  def test_basic_pdf_generation
    puts "\n📄 방법 1: 기본 PDF 생성 테스트"
    filename = "test_basic.pdf"
    
    begin
      @browser.pdf(path: filename)
      
      if File.exist?(filename)
        size = File.size(filename)
        puts "✅ 기본 PDF 생성 성공 (#{size} bytes)"
        File.delete(filename) # 테스트 파일 삭제
      else
        puts "❌ PDF 파일이 생성되지 않음"
      end
    rescue => e
      puts "❌ 기본 PDF 생성 실패: #{e.message}"
    end
  end

  def test_detailed_pdf_generation
    puts "\n📄 방법 2: 상세 옵션 PDF 생성 테스트"
    filename = "test_detailed.pdf"
    
    begin
      @browser.pdf(
        path: filename,
        format: 'A4',
        landscape: false,
        print_background: true,
        margin: {
          top: '2cm',
          bottom: '2cm',
          left: '2cm',
          right: '2cm'
        }
      )
      
      if File.exist?(filename)
        size = File.size(filename)
        puts "✅ 상세 옵션 PDF 생성 성공 (#{size} bytes)"
        File.delete(filename) # 테스트 파일 삭제
      else
        puts "❌ PDF 파일이 생성되지 않음"
      end
    rescue => e
      puts "❌ 상세 옵션 PDF 생성 실패: #{e.message}"
    end
  end

  def test_minimal_pdf_generation
    puts "\n📄 방법 3: 최소 옵션 PDF 생성 테스트"
    filename = "test_minimal.pdf"
    
    begin
      # 페이지 정리
      @browser.execute("document.querySelectorAll('header, nav, footer').forEach(el => el.style.display = 'none')")
      
      # 최소한의 옵션으로 PDF 생성
      @browser.pdf(
        path: filename,
        format: 'A4'
      )
      
      if File.exist?(filename)
        size = File.size(filename)
        puts "✅ 최소 옵션 PDF 생성 성공 (#{size} bytes)"
        puts "🎉 PDF 생성이 가능한 환경입니다!"
        
        # 실제 파일명으로 복사
        final_filename = "construction_permit_debug.pdf"
        FileUtils.cp(filename, final_filename)
        puts "✅ 최종 파일 생성: #{final_filename}"
        
        File.delete(filename) # 테스트 파일 삭제
      else
        puts "❌ PDF 파일이 생성되지 않음"
        puts "💡 Chrome PDF 기능에 문제가 있을 수 있습니다."
      end
    rescue => e
      puts "❌ 최소 옵션 PDF 생성 실패: #{e.message}"
      puts "💡 가능한 해결방법:"
      puts "   1. Chrome 재설치"
      puts "   2. 다른 PDF 생성 라이브러리 사용 (wkhtmltopdf 등)"
      puts "   3. 브라우저의 인쇄 기능 사용"
    end
  end
end

# 실행
if __FILE__ == $0
  puts "🔍 PDF 생성 디버그 도구"
  puts "이 도구는 PDF 생성이 실패하는 원인을 찾아줍니다."
  puts "=" * 60
  
  debugger = DebugPDFGenerator.new
  debugger.debug_and_generate
  
  puts "\n" + "=" * 60
  puts "🎯 디버깅 완료!"
  puts "위의 결과를 바탕으로 PDF 생성 가능 여부를 확인하세요."
end
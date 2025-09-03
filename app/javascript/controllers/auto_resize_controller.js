import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.resize()
    this.scrollToBottom()
  }

  resize() {
    this.element.style.height = 'auto'
    this.element.style.height = this.element.scrollHeight + 'px'
  }

  scrollToBottom() {
    const chatMessages = document.getElementById('chatMessages')
    if (chatMessages) {
      chatMessages.scrollTop = chatMessages.scrollHeight
    }
  }
}
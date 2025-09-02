import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "input", "form"]

  connect() {
    this.scrollToBottom()
    this.focusInput()
  }

  scrollToBottom() {
    if (this.hasMessagesTarget) {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    }
  }

  focusInput() {
    if (this.hasInputTarget) {
      this.inputTarget.focus()
    }
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      if (this.hasFormTarget) {
        this.formTarget.requestSubmit()
      }
    }
  }

  beforeSubmit() {
    if (this.hasInputTarget) {
      this.inputTarget.disabled = true
    }
  }
}
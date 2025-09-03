class ChatsController < ApplicationController
  before_action :ensure_session_id

  def index
    @chats = Chat.for_session(session_id).ordered
    @chat = Chat.new
  end

  def create
    @chat = Chat.new(chat_params.merge(role: 'user', session_id: session_id))
    
    if @chat.save
      # Create AI response
      ai_response = generate_ai_response(@chat.message)
      Chat.create!(
        message: ai_response,
        role: 'assistant',
        session_id: session_id
      )
      
      redirect_to chats_path
    else
      @chats = Chat.for_session(session_id).ordered
      render :index, status: :unprocessable_entity
    end
  end

  private

  def chat_params
    params.require(:chat).permit(:message)
  end

  def ensure_session_id
    session[:chat_session_id] ||= SecureRandom.uuid
  end

  def session_id
    session[:chat_session_id]
  end

  def generate_ai_response(user_message)
    # Simple AI responses for demonstration
    # In a real app, you'd integrate with OpenAI, Claude, or similar
    responses = {
      /hello|hi|hey/i => "Hello! How can I help you today?",
      /how are you/i => "I'm doing great, thank you for asking! How about you?",
      /what.*name/i => "I'm your AI assistant. You can call me ChatBot!",
      /weather/i => "I don't have access to real-time weather data, but I'd recommend checking a weather service for current conditions.",
      /time/i => "The current time is #{Time.current.strftime('%I:%M %p')}.",
      /help/i => "I'm here to help! You can ask me questions, have a conversation, or just chat about anything.",
      /bye|goodbye/i => "Goodbye! It was nice chatting with you. Feel free to come back anytime!"
    }

    response = responses.find { |pattern, _| user_message.match?(pattern) }
    response ? response[1] : "That's interesting! Tell me more about that."
  end
end

class Chat < ApplicationRecord
  validates :message, presence: true
  validates :role, inclusion: { in: %w[user assistant] }
  validates :session_id, presence: true

  scope :for_session, ->(session_id) { where(session_id: session_id) }
  scope :ordered, -> { order(:created_at) }
end

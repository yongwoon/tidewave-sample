class ScrapedArticle < ApplicationRecord
  validates :title, presence: true
  validates :link, presence: true
  validates :scrape_session_id, presence: true
  
  scope :for_session, ->(session_id) { where(scrape_session_id: session_id) }
end

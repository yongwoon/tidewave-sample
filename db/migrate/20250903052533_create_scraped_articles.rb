class CreateScrapedArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :scraped_articles do |t|
      t.text :title
      t.text :link
      t.string :date
      t.string :scrape_session_id

      t.timestamps
    end
  end
end

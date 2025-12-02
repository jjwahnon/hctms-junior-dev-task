class Task < ApplicationRecord
  validates :title, presence: true

  enum :status, { 
    pending: "pending", 
    in_progress: "in_progress", 
    completed: "completed", 
    failed: "failed"
  }

  scope :overdue, -> {
    where("due_date < ?", Time.current)
  }
  scope :upcoming, -> {
    where("due_date >= ?", Time.current)
  }
end

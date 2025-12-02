# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

#Seeding the database to create tasks for development.
Task.create!(
  title: "Review case file - Smith v Jones",
  description: "Review and organize case documents for trial hearing on 15th Dec",
  status: "in_progress",
  due_date: 2.days.from_now
)

Task.create!(
  title: "Prepare witness statements",
  description: "Compile witness statements and prepare summaries for prosecution team",
  status: "pending",
  due_date: 5.days.from_now
)

Task.create!(
  title: "Follow up on missing evidence",
  description: "Contact police department regarding missing forensic evidence from case #2024-001",
  status: "pending",
  due_date: 1.day.from_now
)

Task.create!(
  title: "Schedule expert witness consultation",
  description: "Arrange meeting with medical examiner for case review",
  status: "pending",
  due_date: 3.days.from_now
)

Task.create!(
  title: "File motion to dismiss",
  status: "completed",
  due_date: 1.day.ago
)

Task.create!(
  title: "Prepare sentencing recommendation",
  description: "Research sentencing guidelines and prepare recommendation for guilty plea",
  status: "in_progress",
  due_date: 4.hours.from_now
)

Task.create!(
  title: "Update case management system",
  description: "Input hearing outcomes and update court records",
  status: "pending",
  due_date: 6.hours.from_now
)
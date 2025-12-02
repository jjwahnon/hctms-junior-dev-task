class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.string :title
      t.text :description
      t.string :status
      t.datetime :due_date

      t.timestamps
    end
  end
  add_index :tasks, :status
  add_index :tasks, :due_date
end

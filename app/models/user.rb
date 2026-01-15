class User < ApplicationRecord
  has_secure_password
  
  validates :email, presence: true, uniqueness: true
  validates :password, presence: true, length: { minimum: 6 }, if: :new_record?
  validates :password, length: { minimum: 6 }, if: proc { |u| u.password.present? }
end

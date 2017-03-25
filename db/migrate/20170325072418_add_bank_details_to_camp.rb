class AddBankDetailsToCamp < ActiveRecord::Migration
  def change
    add_column :camps, :dreamscholarship_bank_account_holder_id, :string, limit: 10
    add_column :camps, :dreamscholarship_bank_account_holder_address, :string, limit: 255
  end
end

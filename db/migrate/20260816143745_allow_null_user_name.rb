class AllowNullUserName < ActiveRecord::Migration[8.1]
  def up
    change_column_null :users, :name, true
  end

  def down
    # Rollback is lossy — nil names become empty string to satisfy NOT NULL
    User.where(name: nil).update_all(name: "")
    change_column_null :users, :name, false
  end
end

class AddFeeAndTaxToTrades < ActiveRecord::Migration[8.0]
  def change
    add_column :trades, :fee, :decimal, precision: 19, scale: 4
    add_column :trades, :fee_currency, :string
    add_column :trades, :tax, :decimal, precision: 19, scale: 4
    add_column :trades, :tax_currency, :string
  end
end

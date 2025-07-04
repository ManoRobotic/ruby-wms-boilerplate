require "application_system_test_case"

class Admin::StocksTest < ApplicationSystemTestCase
  setup do
    @admin_stock = stocks(:one)
    @product = @admin_stock.product
    sign_in_admin
  end

  test "visiting the index" do
    visit admin_product_stocks_url(@product)
    assert_selector "h1", text: "Stocks"
  end

  test "should create stock" do
    visit admin_product_stocks_url(@product)
    click_on "New stock"

    fill_in "Amount", with: @admin_stock.amount
    fill_in "Size", with: @admin_stock.size
    click_on "Create Stock"

    assert_text "Stock was successfully created"
    click_on "Back"
  end

  test "should update Stock" do
    visit admin_product_stock_url(@product, @admin_stock)
    click_on "Edit this stock", match: :first

    fill_in "Amount", with: @admin_stock.amount
    fill_in "Size", with: @admin_stock.size
    click_on "Update Stock"

    assert_text "Stock was successfully updated"
    click_on "Back"
  end

  test "should destroy Stock" do
    visit admin_product_stock_url(@product, @admin_stock)
    click_on "Destroy this stock", match: :first

    assert_text "Stock was successfully destroyed"
  end
end

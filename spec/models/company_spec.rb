require 'rails_helper'

RSpec.describe Company, type: :model do
  describe 'validations' do
    it 'allows valid printer_model values' do
      company = Company.new(name: 'Test Company')
      
      company.printer_model = 'zebra'
      expect(company).to be_valid
      
      company.printer_model = 'tsc'
      expect(company).to be_valid
    end

    it 'does not allow invalid printer_model values' do
      company = Company.new(name: 'Test Company', printer_model: 'invalid')
      expect(company).not_to be_valid
      expect(company.errors[:printer_model]).to include("must be either 'zebra' or 'tsc'")
    end

    it 'allows printer_model to be nil initially' do
      company = Company.new(name: 'Test Company')
      expect(company).to be_valid
    end
  end
end
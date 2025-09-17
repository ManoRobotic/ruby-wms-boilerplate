require 'rails_helper'

RSpec.describe Api::ProductionOrdersController, type: :controller do
  describe 'POST #create' do
    let(:company) { create(:company, name: 'Flexiempaques') }
    let(:warehouse) { create(:warehouse, company: company) }
    let(:product) { create(:product, company: company) }
    
    let(:valid_params) do
      {
        company_name: 'Flexiempaques',
        production_order: {
          product_id: product.id,
          quantity_requested: 1000,
          warehouse_id: warehouse.id,
          priority: 'high',
          notes: 'Urgent order for Flexiempaques client',
          no_opro: 'OP-2025-010'
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new production order' do
        expect {
          post :create, params: valid_params
        }.to change(ProductionOrder, :count).by(1)
        
        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)['message']).to eq('Production order created successfully')
      end
    end

    context 'with invalid company name' do
      let(:invalid_params) { valid_params.merge(company_name: 'NonExistentCompany') }

      it 'returns not found error' do
        post :create, params: invalid_params
        
        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)['error']).to eq('Company not found')
      end
    end
  end

  describe 'POST #batch' do
    let(:company) { create(:company, name: 'Flexiempaques') }
    let(:warehouse) { create(:warehouse, company: company) }
    let(:product1) { create(:product, company: company) }
    let(:product2) { create(:product, company: company) }
    
    let(:valid_batch_params) do
      {
        company_name: 'Flexiempaques',
        production_orders: [
          {
            product_id: product1.id,
            quantity_requested: 1000,
            warehouse_id: warehouse.id,
            priority: 'high',
            notes: 'Urgent order for Flexiempaques client',
            no_opro: 'OP-2025-010'
          },
          {
            product_id: product2.id,
            quantity_requested: 500,
            warehouse_id: warehouse.id,
            priority: 'medium',
            notes: 'Second order for Flexiempaques client',
            no_opro: 'OP-2025-011'
          }
        ]
      }
    end

    context 'with valid parameters' do
      it 'creates multiple production orders' do
        expect {
          post :batch, params: valid_batch_params
        }.to change(ProductionOrder, :count).by(2)
        
        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body['message']).to eq('Batch processing completed')
        expect(response_body['results'].length).to eq(2)
        expect(response_body['results'][0]['status']).to eq('success')
        expect(response_body['results'][1]['status']).to eq('success')
      end
    end

    context 'with invalid company name' do
      let(:invalid_batch_params) { valid_batch_params.merge(company_name: 'NonExistentCompany') }

      it 'returns not found error' do
        post :batch, params: invalid_batch_params
        
        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)['error']).to eq('Company not found')
      end
    end

    context 'with empty production orders array' do
      let(:empty_batch_params) do
        {
          company_name: 'Flexiempaques',
          production_orders: []
        }
      end

      it 'returns bad request error' do
        post :batch, params: empty_batch_params
        
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('No production orders provided')
      end
    end

    context 'with some invalid orders' do
      let(:invalid_batch_params) do
        {
          company_name: 'Flexiempaques',
          production_orders: [
            {
              product_id: product1.id,
              quantity_requested: 1000,
              warehouse_id: warehouse.id,
              priority: 'high',
              notes: 'Valid order',
              no_opro: 'OP-2025-010'
            },
            {
              # Missing required fields
              notes: 'Invalid order'
            }
          ]
        }
      end

      it 'processes valid orders and reports errors for invalid ones' do
        expect {
          post :batch, params: invalid_batch_params
        }.to change(ProductionOrder, :count).by(1)
        
        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body['message']).to eq('Batch processing completed')
        expect(response_body['results'].length).to eq(2)
        
        # First order should be successful
        expect(response_body['results'][0]['status']).to eq('success')
        
        # Second order should have errors
        expect(response_body['results'][1]['status']).to eq('error')
      end
    end
  end
end
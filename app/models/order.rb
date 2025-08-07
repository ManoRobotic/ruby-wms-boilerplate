class Order < ApplicationRecord
    # Original associations
    has_many :order_products, dependent: :destroy
    has_many :products, through: :order_products

    # WMS associations
    belongs_to :warehouse, optional: true
    belongs_to :wave, optional: true
    has_many :pick_lists, dependent: :destroy
    has_many :shipments, dependent: :destroy
    has_many :inventory_transactions, as: :reference, dependent: :destroy

    # Enums for status
    enum :status, {
      pending: 0,
      processing: 1,
      shipped: 2,
      delivered: 3,
      cancelled: 4
    }

    # Validations
    validates :customer_email, presence: true, format: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i, message: "is not a valid email address" }
    validates :total, presence: true, numericality: { greater_than: 0 }
    validates :address, presence: true
    validates :status, presence: true
    validates :payment_id, uniqueness: true, allow_nil: true

    # WMS validations
    validates :order_type, presence: true
    validates :fulfillment_status, presence: true
    validates :priority, presence: true

    # WMS Enums
    ORDER_TYPES = %w[sales_order purchase_order transfer_order return_order].freeze
    FULFILLMENT_STATUSES = %w[pending allocated picked packed shipped delivered cancelled].freeze
    PRIORITIES = %w[low medium high urgent].freeze

    validates :order_type, inclusion: { in: ORDER_TYPES }, allow_nil: true
    validates :fulfillment_status, inclusion: { in: FULFILLMENT_STATUSES }, allow_nil: true
    validates :priority, inclusion: { in: PRIORITIES }, allow_nil: true

    # Scopes
    scope :today, -> { where(created_at: Date.current.all_day) }
    scope :this_week, -> { where(created_at: 1.week.ago..Time.current) }
    scope :this_month, -> { where(created_at: 1.month.ago..Time.current) }
    scope :by_email, ->(email) { where(customer_email: email) }
    scope :recent, -> { order(created_at: :desc) }
    scope :with_payment_id, -> { where.not(payment_id: nil) }

    # WMS scopes
    scope :by_order_type, ->(type) { where(order_type: type) }
    scope :by_fulfillment_status, ->(status) { where(fulfillment_status: status) }
    scope :by_priority, ->(priority) { where(priority: priority) }
    scope :by_warehouse, ->(warehouse) { where(warehouse: warehouse) }
    scope :ready_to_ship, -> { where(fulfillment_status: "packed") }
    scope :sales_orders, -> { where(order_type: "sales_order") }

    # Class methods for analytics
    def self.revenue_for_period(start_date, end_date)
      delivered.where(created_at: start_date..end_date).sum(:total)
    end

    def self.count_for_period(start_date, end_date)
      where(created_at: start_date..end_date).count
    end

    def self.average_order_value_for_period(start_date, end_date)
      where(created_at: start_date..end_date).average(:total)
    end

    def self.revenue_by_day(days_back = 7)
      end_date = Date.current
      start_date = (days_back - 1).days.ago.to_date

      (start_date..end_date).each_with_object({}) do |date, hash|
        # Include processed, shipped, and delivered orders for revenue calculation
        revenue = where(status: [ :processing, :shipped, :delivered ])
                    .where(created_at: date.all_day)
                    .sum(:total)
        hash[date] = revenue
      end
    end

    # Instance methods
    def fulfilled?
      delivered?
    end

    def can_be_cancelled?
      pending? || processing?
    end

    def total_items
      order_products.sum(:quantity)
    end

    # WMS methods
    def display_number
      "ORD-#{id.to_s.rjust(8, '0')}"
    end

    def can_create_pick_list?
      (order_type.nil? || order_type == "sales_order") &&
      (fulfillment_status.nil? || fulfillment_status == "pending") &&
      warehouse.present? && order_products.any?
    end

    def sales_order?
      order_type.nil? || order_type == "sales_order"
    end

    def create_pick_list!(admin = nil)
      return nil unless can_create_pick_list?

      admin ||= Admin.first
      PickList.create_for_order(self, admin: admin)
    end

    def total_with_currency
      "#{total} MXN"
    end

    def formatted_total
      "$#{total}"
    end

    # Callbacks
    before_save :normalize_email
    before_save :set_wms_defaults
    after_create :generate_payment_id_if_blank
    after_create :notify_admins_of_new_order

    private

    def normalize_email
      self.customer_email = customer_email.downcase if customer_email.present?
    end

    def generate_payment_id_if_blank
      if payment_id.blank?
        self.update_column(:payment_id, "ORD-#{SecureRandom.hex(8).upcase}")
      end
    end

    def set_wms_defaults
      self.order_type ||= "sales_order"
      self.fulfillment_status ||= "pending"
      self.priority ||= "medium"
      self.warehouse ||= Warehouse.main_warehouse if sales_order?
    end

    def notify_admins_of_new_order
      # Notify all admins of new order
      Admin.find_each do |admin|
        Notification.create_order_alert(
          admin: admin,
          order: self,
          message: "Nueva orden ##{payment_id} por #{formatted_total} de #{customer_email}"
        )
      rescue => e
        Rails.logger.error "Failed to create notification for admin #{admin.id}: #{e.message}"
      end
    end
end

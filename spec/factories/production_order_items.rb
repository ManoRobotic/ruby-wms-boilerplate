FactoryBot.define do
  factory :production_order_item do
    production_order { nil }
    folio_consecutivo { "MyString" }
    peso_bruto { "9.99" }
    peso_neto { "9.99" }
    metros_lineales { "9.99" }
    peso_core_gramos { 1 }
    status { "MyString" }
    micras { 1 }
    ancho_mm { 1 }
    altura_cm { 1 }
  end
end

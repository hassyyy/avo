class Avo::Tab
  include Avo::Concerns::IsResourceItem

  # @todo: fix the view
  class_attribute :view, default: :show
  class_attribute :item_type, default: :tab

  attr_reader :name
  attr_accessor :items_holder
  attr_accessor :description

  delegate :view, to: :self
  delegate :items, :add_item, to: :items_holder

  def initialize(name: nil, description: nil)
    @name = name
    @description = description
    @items_holder = Avo::ItemsHolder.new
  end
end

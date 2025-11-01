Sequel::Model.plugin :json_serializer
Sequel::Model.plugin :timestamps, update_on_create: true
Sequel::Model.plugin :tactical_eager_loading
Sequel.split_symbols = true # SEQUEL DEPRECATION WARNING: Symbol splitting is deprecated and will be removed in Sequel 5.  Either set Sequel.split_symbols = true or make changes

require 'philtre'
require_relative 'serializer'

class Sequel::Model
  PER_PAGE = 25

  # finders for single row
  def self.find_value_by_attrs(value, attrs)
    where(attrs).get(value)
  end

  def self.find_values_by_attrs(values, attrs)
    where(attrs).select(*values).first
  end

  def self.find_all_values_by_attrs(attrs)
    where(attrs).first
  end

  # pagination with total count
  def self.paginate(current_page = 1, owner_criteria = {}, search_criteria = {})

    criteria = owner_criteria.merge(search_criteria ? search_criteria : {})

    count = Philtre.new(criteria).apply(self.dataset).count

    # select only public attrs in reversed order
    dataset = reverse(:id).select(*self::PUBLIC_ATTRS)

    # exclude reversal trx type
    dataset = dataset.exclude(transaction_type: 'card_reversal') if self == Transaction

    # paginate dataset
    dataset = dataset.limit((self::PER_PAGE rescue PER_PAGE))
              .offset((self::PER_PAGE rescue PER_PAGE) * (current_page.to_i - 1))

    # filter dataset
    filtered_dataset = Philtre.new(criteria).apply(dataset)

    [ (self::PER_PAGE rescue PER_PAGE),
      count,
      filtered_dataset
    ]
  end

  # update instance with audit, user_id is changing the record
  def self.update(id, attrs={}, user_id = nil, non_audited_attrs = [])
    instance = self[id]
    puts "=> updating #{instance.class} ##{id} ..."
    if instance.update(attrs)
      instance.audit(user_id, non_audited_attrs)
    end
    instance
  end

  def audit(user_id, non_audited_attrs)
    puts "=> auditing #{model.name} ..."
    add_audit(  model_name: model.name,
                user_id: user_id,
                diff: previous_changes.reject {|k,v| ([:created_at, :updated_at] + non_audited_attrs).include?(k)})
  end

  def add_audit_message(user_id, msg)
    puts "=> adding audit message: #{msg}"
    add_audit model_name: model.name, user_id: user_id, diff: {'System message' => ['', msg]}
  end

end

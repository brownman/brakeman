require 'checks/base_check'

#Checks for mass assignments to models.
#
#See http://guides.rubyonrails.org/security.html#mass-assignment for details
class CheckMassAssignment < BaseCheck
  Checks.add self

  def run_check
    return if mass_assign_disabled? tracker

    models = []
    tracker.models.each do |name, m|
      if parent?(tracker, m, :"ActiveRecord::Base") and m[:attr_accessible].nil?
        models << name
      end
    end

    return if models.empty?

    @results = Set.new

    calls = tracker.find_call models, [:new,
      :attributes=, 
      :update_attribute, 
      :update_attributes, 
      :update_attributes!,
      :create,
      :create!]

    calls.each do |result|
      process result
    end
  end

  #All results should be Model.new(...) or Model.attributes=() calls
  def process_result res
    call = res[-1]

    check = check_call call

    if check and not @results.include? call
      @results << call

      if include_user_input? call[3]
        confidence = CONFIDENCE[:high]
      else
        confidence = CONFIDENCE[:med]
      end
      
      warn :result => res, 
        :warning_type => "Mass Assignment", 
        :message => "Unprotected mass assignment",
        :line => call.line,
        :code => call, 
        :confidence => confidence
    end
    res
  end

  #Want to ignore calls to Model.new that have no arguments
  def check_call call
    args = process call[3]
    if args.length <= 1 #empty new()
      false
    elsif hash? args[1]
      #Still should probably check contents of hash
      false
    else
      true
    end
  end

end

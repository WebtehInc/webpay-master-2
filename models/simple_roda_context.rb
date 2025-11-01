# mock for roda request/response context if using DStruct classes directly (outside the roda router)
class SimpleRodaContext
  attr_accessor :user_id, :params, :output, :suppress_output

  def initialize user_id, params
    @user_id = user_id
    @params = params
  end

  def render_error errors
    @output = errors
    puts errors.inspect unless suppress_output
  end

  def render_success success
    @output = success
    puts success.inspect unless suppress_output
  end
end

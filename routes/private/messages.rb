WebPay.route('messages') do |r|
  puts '=> getting messages ...'

  r.post ':id/reply' do |id|
    puts '=> replying to message ...'
    ReplyToMessage.call(id, self)
  end
  r.post ':id/read' do |id|
    puts '=> reading message ...'
    [Message.where(id: id, user_id: user_id).update(read_by_user: true)]
  end
  r.post ':page' do |page|
    r.paginated_dataset(*Message.paginate(page, {user_id: user_id}, params[:search])).all
  end
end
WebPay.route('profile') do |r|

  r.get 'logins' do
    puts '=> getting profile logins ...'
    LoginTrail.where(user_id: user_id).reverse(:id).limit(5).all
  end

  r.get 'changes' do
    puts '=> getting profile changes ...'
    Audit.where(model_id: user_id, model_name: 'User').select(:created_at, :diff).reverse(:id).limit(5).all
  end

  r.get 'documents' do
    puts '=> getting documents ...'
    Document.select(*Document::PUBLIC_ATTRS).where(user_id: user_id).reverse(:id).all
  end

  r.post 'settings/update' do
    # authorize!
    puts '=> updating profile setings...'
    User[user_id].update(settings: params)
    params
  end

  r.post 'update' do
    authorize!
    puts '=> updating profile ...'
    UpdateProfile.call(self)
  end

  r.post 'upload' do
    puts '=> uploading document...'
    UploadDocument.call(self)
  end

end
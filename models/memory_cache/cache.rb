module MemoryCache

  def self.fetch_setting(name)
    # load from memory if its there
    form_cache = MEMORY_STORE.get(name)
    return form_cache if form_cache

    # or load from db and write it to memory
    setting = Setting.where(name: name).first
    MEMORY_STORE.set(setting[:name], setting.value)
    return setting.value
  end

end

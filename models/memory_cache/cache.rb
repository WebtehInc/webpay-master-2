module MemoryCache

  def self.fetch_setting(name)
    # load from memory if its there
    form_cache = MEMORY_STORE.get(name)
    return form_cache if form_cache

    # or load from db and write it to memory
    setting = Setting.where(name: name).first

    # Check if setting exists before accessing it
    unless setting
      LOGGER.error "Setting '#{name}' not found in database!"
      raise "Required setting '#{name}' is missing from database. Please add it to the settings table."
    end

    MEMORY_STORE.set(setting[:name], setting.value)
    return setting.value
  end

end

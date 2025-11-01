module DownloadConfig
  extend self

  DOWNLOADS_FOLDER  = 'downloads'
  MAIN_APP_PREFIX   = 'mainapp'
  TTL               = 24 * 60 * 60 # 1 day

  def call
    # return from cache if its there
    cached_config = MemoryStore.get('download_config')
    return cached_config if cached_config

    file_names = Dir.entries(DOWNLOADS_FOLDER).sort.reverse
    main_app_file_name = file_names.find{|f| f.start_with? MAIN_APP_PREFIX}

    return {mainapp: false} unless main_app_file_name

    download_config = {
      mainapp: {  name: main_app_file_name,
                  version: main_app_file_name.split('_').last,
                  checksum: Digest::SHA512.file("#{DOWNLOADS_FOLDER}/#{main_app_file_name}").hexdigest}}

    MemoryStore.set('download_config', download_config, TTL)
    download_config
  end

  def reset!
    MemoryStore.delete('download_config')
    call
  end
end

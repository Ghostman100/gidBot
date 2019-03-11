class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext
  require 'date'

  def callback_query(data)
    # if session[:search_steps].last == :ccalendar
    array = data.scan(/\w+/)
    action = array[0]
    year = array[1]
    month = array[2]
    day = array[3]
    ret_data = nil
    query = update["callback_query"]
    if action == "NEXT"
      next_month = Date.new(year.to_i, month.to_i, day.to_i) >> 1
      bot.edit_message_text(
          text: 'Please choose a date',
          chat_id: query["message"]["chat"]["id"],
          message_id: query["message"]["message_id"],
          reply_markup: {
              inline_keyboard: create_calendar(next_month.year.to_i, next_month.month.to_i),
              hide_keyboard: true
          }
      )
    elsif action == "PREV"
      prev_month = Date.new(year.to_i, month.to_i, day.to_i) >> -1
      bot.edit_message_text(
          text: 'Please choose a date',
          chat_id: query["message"]["chat"]["id"],
          message_id: query["message"]["message_id"],
          reply_markup: {
              inline_keyboard: create_calendar(prev_month.year.to_i, prev_month.month.to_i),
              hide_keyboard: true
          }
      )
    elsif action == "IGNORE"
      bot.answer_callback_query(callback_query_id: query["id"])
    elsif action == "DAY"
      ret_data = Date.new(year.to_i, month.to_i, day.to_i)
      tour_date(ret_data.strftime("%d.%m.%Y").to_s)
    else
      bot.answer_callback_query(callback_query_id: query["id"], text: "Something went wrong!")
    end
  end

  def add_note(id, username, first_name)
    respond_with :message, text: "Запоняется таблица"
    google_session = GoogleDrive::Session.from_config("config.json")

    ws = google_session.spreadsheet_by_key("1drEq6fjK9Ew_cXA2f_3jbcURs8Kmk0GdioyHHXYtzIQ").worksheets[0]
    row = ws.num_rows + 1
    ws[row, 1] = (row - 1).to_s
    ws[row, 2] = session[:date]
    ws[row, 3] = session[:name]
    ws[row, 4] = session[:size]
    ws[row, 5] = session[:cost]
    ws[row, 6] = session[:time]
    ws[row, 7] = session[:follow_up]
    ws[row, 8] = id
    ws[row, 9] = username
    ws[row, 10] = first_name
    p from['id']
    folder = google_session.collection_by_id("1i7nFL04qRX31SW8gSlpfYe8PU4UMh_6M")
    checks_folder = google_session.collection_by_id("1SqBf5NNVqO1iz-6KEga-MQi8ePLbHh8p")
    main_photo = google_session.collection_by_id("12jwNBQKtCWjIrA1FmMoRRD2JmdBwS_Ze")
    a = checks_folder.upload_from_file("public/checks/#{id}.#{session[:format]}", "#{row - 1}_#{id}.#{session[:format]}", convert: false)
    ws[row, 11] = a.web_view_link
    photo = main_photo.create_subcollection("#{row -1}_#{id}_#{session[:name]}")
    ws[row, 12] = "https://drive.google.com/drive/u/0/folders/#{photo.id}"
    session[:photo_id] = photo.id
    session[:row] = row
    ws.save
    session[:photo_number] = 1
    save_context :photo
    respond_with :message, text: "Загрузи сюда фотографии с тура (до 10 штук)", reply_markup: {
        keyboard: [["Завершить"]],
        resize_keyboard: true,
        one_time_keyboard: true,
        selective: true
    }
  end

  def add_tour_photo(path, format)
    google_session = GoogleDrive::Session.from_config("config.json")
    photo_folder = google_session.collection_by_id(session[:photo_id])
    photo_folder.upload_from_file(path, "#{session[:row]}_#{session[:photo_number]}.#{format}", convert: false)
    session[:photo_number] += 1
  end

  def start!(*)
    # save_context :tour_date
    respond_with :message, text: "Hello"
  end

  def new!(*)
    # save_context :tour_date
    # respond_with :message, text: "Дата тура?"
    ccalendar
  end

  def tour_date(value = nil, *)
    session[:date] = value
    save_context :tour_name
    respond_with :message, text: "Какой был тур?", reply_markup: {
        keyboard: [["Icons", "Metro", "Market", "Vodka"], ["Total", "Made in", "Bike", "Tula", "Private"]],
        resize_keyboard: true,
        one_time_keyboard: true,
        selective: true
    }
  end

  def tour_name(*)
    session[:name] = self.update['message']['text']
    save_context :tour_size
    respond_with :message, text: "Сколько было туристов?"
  end

  def tour_size(*)
    session[:size] = self.update['message']['text']
    save_context :tour_time
    respond_with :message, text: "Напиши общую сумму затрат по туру (в формате 567)"
  end

  def tour_time(*)
    session[:cost] = self.update['message']['text']
    save_context :tour_follow_up
    respond_with :message, text: "Сколько часов длился тур (в формате 7,5)?"
  end

  def tour_follow_up(*)
    session[:time] = self.update['message']['text']
    save_context :tour_cost
    respond_with :message, text: "Ты уже отправил follow up письмо с фотографиями туристу (если нет, то почему)?"
  end

  def tour_cost(*)
    session[:follow_up] = self.update['message']['text']
    save_context :tour_check
    respond_with :message, text: "Скинь фотки чеков(PNG)"
  end

  def tour_check(*)
    if self.update['message']['document'] && self.update['message']['document']['mime_type'] && self.update['message']['document']['mime_type'].split("/").first == "image"
      #file_id = Telegram.bot.get_file(file_id: self.update['message']['document']['file_id'])
      session[:format] = suf = self.update['message']['document']['mime_type'].split("/").last
      path = Telegram.bot.get_file(file_id: self.update['message']['document']['file_id'])['result']['file_path']
      File.open("public/checks/#{from['id']}.#{suf}", 'wb') do |fo|
        fo.write open("https://api.telegram.org/file/bot674701815:AAEf_wfVLTaw3MftfMLgfB3inSCjFwhjShQ/#{path}").read
      end
      add_note(from['id'], from['username'], from['first_name'])
    elsif self.update['message']['photo']
      path = Telegram.bot.get_file(file_id: self.update['message']['photo'][-1]['file_id'])['result']['file_path']
      session[:format] = suf = "https://api.telegram.org/file/bot674701815:AAEf_wfVLTaw3MftfMLgfB3inSCjFwhjShQ/#{path}".split(".").last
      File.open("public/checks/#{from['id']}.#{suf}", 'wb') do |fo|
        fo.write open("https://api.telegram.org/file/bot674701815:AAEf_wfVLTaw3MftfMLgfB3inSCjFwhjShQ/#{path}").read
      end
      add_note(from['id'], from['username'], from['first_name'])
    else
      save_context :tour_check
      respond_with :message, text: "Пожалуйста, приложите фото чеков"
    end
  end

  def photo(value = nil, *)
    if value == "Завершить"
      respond_with :message, text: "Спасибо, скоро ты получишь выплату на карту"
      return
    end
    save_context :photo
    if self.update['message']['document'] && self.update['message']['document']['mime_type'] && self.update['message']['document']['mime_type'].split("/").first == "image"
      session[:photo_format] = suf = self.update['message']['document']['mime_type'].split("/").last
      path = Telegram.bot.get_file(file_id: self.update['message']['document']['file_id'])['result']['file_path']
      File.open("public/photo/#{session[:photo_number]}_#{from['id']}.#{suf}", 'wb') do |fo|
        fo.write open("https://api.telegram.org/file/bot674701815:AAEf_wfVLTaw3MftfMLgfB3inSCjFwhjShQ/#{path}").read
      end
      add_tour_photo("public/photo/#{session[:photo_number]}_#{from['id']}.#{suf}", suf)
    elsif self.update['message']['photo']
      path = Telegram.bot.get_file(file_id: self.update['message']['photo'][-1]['file_id'])['result']['file_path']
      session[:photo_format] = suf = "https://api.telegram.org/file/bot674701815:AAEf_wfVLTaw3MftfMLgfB3inSCjFwhjShQ/#{path}".split(".").last
      File.open("public/photo/#{session[:photo_number]}_#{from['id']}.#{suf}", 'wb') do |fo|
        fo.write open("https://api.telegram.org/file/bot674701815:AAEf_wfVLTaw3MftfMLgfB3inSCjFwhjShQ/#{path}").read
      end
      add_tour_photo("public/photo/#{session[:photo_number]}_#{from['id']}.#{suf}", suf)
    else
          respond_with :message, text: "Пожалуйста, приложите фото тура"
    end
  end

  def message(*)
    p self.update['message']['chat']['id']
    Telegram.bot.forward_message chat_id: from['id'], from_chat_id: from['id'], message_id: self.update['message']['message_id']
    #   if self.update['message']['document'] && self.update['message']['document']['mime_type'] == "image/png"
  #     #file_id = Telegram.bot.get_file(file_id: self.update['message']['document']['file_id'])
  #     path = Telegram.bot.get_file(file_id: self.update['message']['document']['file_id'])['result']['file_path']
  #     File.open("public/checks/#{from['id']}.png", 'wb') do |fo|
  #       fo.write open("https://api.telegram.org/file/bot674701815:AAEf_wfVLTaw3MftfMLgfB3inSCjFwhjShQ/#{path}").read
  #     end
  #   elsif self.update['message']['photo']
  #     path = Telegram.bot.get_file(file_id: self.update['message']['photo'][0]['file_id'])['result']['file_path']
  #     p "https://api.telegram.org/file/bot674701815:AAEf_wfVLTaw3MftfMLgfB3inSCjFwhjShQ/#{path}".split(".").last
  #   else
  #     save_context :tour_check
  #     respond_with :message, text: "Пожалуйста, приложите изображение как файл (без сжатия), а не как фотографию."
  #   end
  end

  def ccalendar(*) #(*params)
    # add_search_step(:ccalendar)
    save_context :tour_name
    respond_with :message, text: 'Please choose a date', reply_markup: {
        inline_keyboard: create_calendar(Time.now.year, Time.now.month),
        hide_keyboard: true
    }
  end


  def create_callback_data(action, year, month, day)
    return [action, year.to_s, month.to_s, day.to_s].join(";")
  end

  def month_name(month)
    {1 => "January", 2 => "February", 3 => "March", 4 => "April", 5 => "May", 6 => "June", 7 => "July", 8 => "August", 9 => "September", 10 => "October", 11 => "November", 12 => "December"}[month]
  end


  def calendar(month, year)
    a = []
    str = "15.#{month}.#{year}"
    a[Date.parse(str).beginning_of_month.cwday - 1] = 1
    list = (2..Date.parse(str).end_of_month.day).to_a
    a = a.concat(list).each_slice(7).to_a
    a.each do |val|
      val.concat([nil] * (7 - val.length))
    end
    a
  end

  def create_calendar(year, month)
    year_now = Time.now.strftime("%Y")
    month_now = Time.now.strftime("%m")
    if year == nil
      year = year_now
    end
    if month == nil
      month = month_now
    end
    data_ignore = create_callback_data("IGNORE", year, month, 0)
    keyboard = []

    row = []
    row.push(text: "#{month_name(month)} #{year.to_s}", callback_data: data_ignore)
    keyboard.push(row)

    row = []
    ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"].each do |day|
      row.push(text: day, callback_data: data_ignore)
    end
    keyboard.push(row)

    my_calendar = calendar(month, year)
    my_calendar.each do |week|
      row = []
      week.each do |day|
        if day == nil
          row.push(text: " ", callback_data: data_ignore)
        else
          row.push(text: day.to_s, callback_data: create_callback_data("DAY", year, month, day))
        end
      end
      keyboard.push(row)
    end

    row = []
    row.push(text: "<", callback_data: create_callback_data("PREV", year, month, 1))
    row.push(text: " ", callback_data: data_ignore)
    row.push(text: ">", callback_data: create_callback_data("NEXT", year, month, 1))
    keyboard.push(row)
    keyboard
    # p keyboard
  end
  # end

end
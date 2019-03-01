class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext

  def add_note(id, username, first_name)
    google_session = GoogleDrive::Session.from_config("config.json")

    ws = google_session.spreadsheet_by_key("1drEq6fjK9Ew_cXA2f_3jbcURs8Kmk0GdioyHHXYtzIQ").worksheets[0]
    row = ws.num_rows + 1
    ws[row, 1] = (row - 1).to_s
    ws[row, 2] = session[:date]
    ws[row, 3] = session[:name]
    ws[row, 4] = session[:size]
    ws[row, 5] = session[:cost]
    ws[row, 6] = id
    ws[row, 7] = username
    ws[row, 8] = first_name
    p from['id']
    ws.save
  end

  def start!(*)
    # save_context :tour_date
    respond_with :message, text: "Hello"
  end

  def new!(*)
    save_context :tour_date
    respond_with :message, text: "Дата тура?"
  end

  def tour_date(value = nil, *)
    session[:date] = self.update['message']['text']
    save_context :tour_name
    respond_with :message, text: "Какой был тур?"
  end

  def tour_name(*)
    session[:name] = self.update['message']['text']
    save_context :tour_size
    respond_with :message, text: "Сколько было туристов?"
  end

  def tour_size(*)
    session[:size] = self.update['message']['text']
    save_context :tour_cost
    respond_with :message, text: "Какие были затраты?"
  end

  def tour_cost(*)
    session[:cost] = self.update['message']['text']
    add_note(from['id'], from['username'], from['first_name'])
  end

  def tour_check(*)
    if self.update['message']['document']['mime_type'] == "image/png"
      file_id = Telegram.bot.get_file(file_id: self.update['message']['document']['file_id'])
      path = Telegram.bot.get_file(file_id: file_id)['result']['file_path']
      File.open("public/checks/#{from['id']}.png", 'wb') do |fo|
        fo.write open("https://api.telegram.org/file/bot674701815:AAEf_wfVLTaw3MftfMLgfB3inSCjFwhjShQ/#{path}").read
      end
    else
      save_context :tour_check
      respond_with :message, text: "Пожалуйста, приложите изображение как файл (без сжатия), а не как фотографию."
    end
  end

  def message(*)
    if self.update['message']['photo'] == "image/png"

    end
  end


end
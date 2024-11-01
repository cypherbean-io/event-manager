require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key').strip
  
  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_phone_numbers(phone)
  cleaned_phone = phone.gsub(/\D/, '')

  case cleaned_phone.length
  when 10
    cleaned_phone
  when 11
    cleaned_phone.start_with?('1') ? cleaned_phone[1..-1] : 'invalid'
  else
    'invalid'
  end
end

puts 'Event Manager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

registration_hours = Hash.new(0)
registration_days = Hash.new(0)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  phone = clean_phone_numbers(row[:homephone])

  reg_date = row[:regdate]
  reg_time = Time.strptime(reg_date, '%m/%d/%y %H:%M')
  registration_hours[reg_time.hour] += 1
  registration_days[reg_time.wday] += 1

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

peak_hour = registration_hours.max_by { |hour, count| count }[0]
peak_day = Date::DAYNAMES[registration_days.max_by { |day, count| count }[0]]

puts "The peak registration hour is #{peak_hour}:00. The peak registration day is #{peak_day}."
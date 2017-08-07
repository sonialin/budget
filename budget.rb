require 'sinatra'
require 'sinatra/reloader'
require 'date'
require 'json'

configure do
  enable :sessions
end

before do
  session[:messages] ||= []
  @budgets = JSON.parse(File.read("data/budgets.json"))
  
  group_budgets_by_month
  calculate_monthly_budgets
end

helpers do
  def sort_by_month(monthly_budgets)
    monthly_budgets.sort_by{|month, budgets| Date.parse(month) }
  end

  def parse_currency(amount)
    "$" + sprintf("%0.02f", amount)
  end
end

def group_budgets_by_month
  @budgets_by_month = {}
  @budgets.each do |budget|
    if !@budgets_by_month[budget['Month']]
      @budgets_by_month[budget['Month']] = [budget]
    else
      @budgets_by_month[budget['Month']] << budget
    end
  end
end

def calculate_monthly_budgets
  @monthly_budgets = {}
  @budgets_by_month.each do |month, budgets|
    if !@monthly_budgets[month]
      @monthly_budgets[month] = 0
    end
    budgets.each do |budget|
      @monthly_budgets[month] += budget['Amount']
    end
  end
end

def format_month(input_month)
  if (1..9).include? input_month.to_i
    '0' + input_month.to_i.to_s
  else
    input_month
  end
end

def update_budgets(new_budget = nil)
  if new_budget
    parsed_budget = {"Item Name" => new_budget["Item Name"], 
                      "Amount" => new_budget["Amount"].to_f,
                      "Month" => "#{new_budget['Year']}/#{format_month(new_budget['Month'])}",
                      "Created at" => Time.now
                    }

    @budgets << parsed_budget
  end

  File.open("data/budgets.json", "w") do |f|
    f.write(JSON.pretty_generate(@budgets))
  end
end

def invalid_input?(budget)
  validate_amount(budget["Amount"])
  validate_date(budget["Month"], budget["Year"])
  session[:messages].any?
end

def empty_field?(budget)
  budget.each do |field, value|
    session[:messages] << "#{field} cannot be empty." if value.empty?
  end
  session[:messages].any?
end

def validate_amount(amount)
  session[:messages] << "Please enter a valid dollar amount" if !(Float(amount) rescue false)
end

def validate_date(month, year)
  session[:messages] << "Please enter a valid month" if !(1..12).include? month.to_i
  session[:messages] << "Please enter a valid year" if !(1900..2100).include? year.to_i
end

get "/" do 
  erb :index
end

get "/new" do 
  erb :new
end

post "/new" do
  new_budget = {"Item Name" => params[:item_name].strip,
            "Amount" => params[:amount],
            "Month" => params[:month],
            "Year" => params[:year]}

  if empty_field?(new_budget) || invalid_input?(new_budget)
    erb :new
  else
    update_budgets(new_budget)
    session[:messages] << "New budget is added."
    redirect "/"
  end
end

post "/:created_at/delete" do
  created_at = params[:created_at]
  budget = @budgets.find {|budget| budget["Created at"] == params[:created_at]}
  @budgets.delete(budget)
  update_budgets
  session[:messages] << "A budget is deleted."
  redirect "/"
end

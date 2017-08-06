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
end

helpers do
  def sort_by_month(budgets)
    budgets.sort_by{|budget| Date.parse(budget["Month"]) }.reverse
  end

  def parse_currency(amount)
    sprintf("%0.02f", amount)
  end
end

def update_budgets(new_budget)
  parsed_budget = {"Item Name" => new_budget["Item Name"].strip, 
                    "Amount" => new_budget["Amount"].to_f,
                    "Month" => "#{new_budget['Month']}-#{new_budget['Year']}"
                  }

  File.open("data/budgets.json", "w") do |f|
    f.write(JSON.pretty_generate(@budgets << parsed_budget))
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
  new_budget = {"Item Name" => params[:item_name],
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
require 'rails_helper'

RSpec.describe "insured/employee_roles/search.html.haml" do
  let(:person) {FactoryGirl.create(:person)}

  before :each do
    assign(:person, person)
    render template: "insured/employee_roles/search.html.haml"
  end

  it "should display the employee search page" do
    expect(rendered).to have_selector('h3', text: 'Personal Information')
    expect(rendered).to have_selector("input[type='text']", count: 5)
    expect(rendered).to have_selector("input[type='radio']", count: 2)
  end
end

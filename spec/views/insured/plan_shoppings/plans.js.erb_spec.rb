require "rails_helper"

RSpec.describe "insured/plan_shoppings/plans.js.erb" do
  let(:hbx_enrollment) { FactoryGirl.build_stubbed(:hbx_enrollment)}
  before :each do
    assign :plans, []
    assign :hbx_enrollment, hbx_enrollment
    render :file => "insured/plan_shoppings/plans.js.erb"
  end

  it "should call aptc" do
    expect(rendered).to match /aptc/
    expect(rendered).to match /elected_pct/
    expect(rendered).to match /updatePlanCost/
  end
end

@watir @screenshots @no-database-cleaner
Feature: Newhire
  Scenario: Individual user hired by employer
    Given Individual has not signed up as an HBX user
      When I visit the Insured portal
      Then Jack Ivl create a new account
      Then I should see a successful sign up message
      And user should see your information page
      When Jack Ivl goes to register as an individual
      When user clicks on continue button
      Then user should see button to continue as an individual
      Then Individual should click on Individual market for plan shopping
      Then Individual should see a form to enter personal information
      When Individual clicks on continue button
      Then Individual should see identity verification page and clicks on submit
      Then Individual should see the dependents form
      And I click on continue button on household info form
      And I click on continue button on group selection page
      And I select three plans to compare
      And I should not see any plan which premium is 0
      And I select a plan on plan shopping page
      And Jack Ivl click on purchase button on confirmation page
      And I click on continue button to go to the individual home page
      And I should see the individual home page
      Then Individual logs out
    Given Employer has not signed up as an HBX user
      When I visit the Employer portal
      Then Jack Doe create a new account
      Then I should see a successful sign up message
      Then I should click on employer portal
      Then Jack Doe creates a new employer profile
      When I go to the Profile tab
      When Employer goes to the benefits tab I should see plan year information
      And Employer should see a button to create new plan year
      And Employer should be able to enter plan year, benefits, relationship benefits
      And Employer should see a success message after clicking on create plan year button
      When Employer goes to the benefits tab I should see plan year information
      Then Employer clicks on publish plan year
      Then Employer should see a published success message without employee
      When Employer clicks on the Employees tab
      When Employer clicks on the add employee button
      Then Employer should see a form to enter information about employee, address and dependents details for Jack Ivl
      And Employer should see employer census family created success message for Jack Ivl
      And Employer should see the status of employee role linked
      Then Employer logs out
      When I visit the Insured portal
      Then Jack Ivl login
      Then I should see a successful sign in message
      And I should see employer hire message
      And Jack Ivl click on continue button on group selection page after hired by employer
      And I select a plan on plan shopping page
      Then I should see the coverage summary page
      When I clicks on Confirm button on the coverage summary page
      Then I should see the receipt page
      Then I should see the "my account" page
      And I should not see employer hire message
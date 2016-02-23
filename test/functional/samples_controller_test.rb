require 'test_helper'

class SamplesControllerTest < ActionController::TestCase

  include AuthenticatedTestHelper

  include SharingFormTestHelper

  test 'new' do
    login_as(Factory(:person))
    get :new
    assert_response :success
    assert assigns(:sample)
  end

  test 'show' do
    get :show, id: populated_patient_sample.id
    assert_response :success
  end

  test 'new with sample type id' do
    login_as(Factory(:person))
    type = Factory(:patient_sample_type)
    get :new, sample_type_id: type.id
    assert_response :success
    assert assigns(:sample)
    assert_equal type, assigns(:sample).sample_type
  end

  test 'create' do
    login_as(Factory(:person))
    type = Factory(:patient_sample_type)
    assert_difference('Sample.count') do
      post :create, sample: { sample_type_id: type.id, title: 'My Sample', full_name: 'George Osborne', age: '22', weight: '22.1', postcode: 'M13 9PL' }
    end
    assert assigns(:sample)
    sample = assigns(:sample)
    assert_equal 'My Sample', sample.title
    assert_equal 'George Osborne', sample.full_name
    assert_equal '22', sample.age
    assert_equal '22.1', sample.weight
    assert_equal 'M13 9PL', sample.postcode
  end

  test 'edit' do
    login_as(Factory(:person))
    get :edit, id: populated_patient_sample.id
    assert_response :success
  end

  test 'update' do
    login_as(Factory(:person))
    sample = populated_patient_sample
    type_id = sample.sample_type.id

    assert_no_difference('Sample.count') do
      put :update, id: sample.id, sample: { title: 'Updated Sample', full_name: 'Jesus Jones', age: '47', postcode: 'M13 9QL' }
    end

    assert assigns(:sample)
    assert_redirected_to assigns(:sample)
    updated_sample = assigns(:sample)
    updated_sample = Sample.find(updated_sample.id)
    assert_equal type_id, updated_sample.sample_type.id
    assert_equal 'Updated Sample', updated_sample.title
    assert_equal 'Jesus Jones', updated_sample.full_name
    assert_equal '47', updated_sample.age
    assert_nil updated_sample.weight
    assert_equal 'M13 9QL', updated_sample.postcode
  end

  test 'associate with project on create' do
    person = Factory(:person_in_multiple_projects)
    login_as(person)
    type = Factory(:patient_sample_type)
    assert person.projects.count >= 3 #incase the factory changes
    project_ids = person.projects[0..1].collect(&:id)
    assert_difference('Sample.count') do
      post :create, sample: { sample_type_id: type.id, title: 'My Sample', full_name: 'George Osborne', age: '22', weight: '22.1', postcode: 'M13 9PL', project_ids:project_ids }
    end
    assert sample=assigns(:sample)
    assert_equal person.projects[0..1].sort,sample.projects.sort
  end

  test 'associate with project on update' do
    person = Factory(:person_in_multiple_projects)
    login_as(person)
    sample = populated_patient_sample
    assert_empty sample.projects
    assert person.projects.count >= 3 #incase the factory changes
    project_ids = person.projects[0..1].collect(&:id)

    put :update, id: sample.id, sample: { title: 'Updated Sample', full_name: 'Jesus Jones', age: '47', postcode: 'M13 9QL',project_ids:project_ids }

    assert sample=assigns(:sample)
    assert_equal person.projects[0..1].sort,sample.projects.sort

  end

  test 'contributor can view' do
    person = Factory(:person)
    login_as(person)
    sample = Factory(:sample, :policy=>Factory(:private_policy), :contributor=>person)
    get :show,:id=>sample.id
    assert_response :success
  end

  test 'non contributor cannot view' do
    person = Factory(:person)
    other_person = Factory(:person)
    login_as(other_person)
    sample = Factory(:sample, :policy=>Factory(:private_policy), :contributor=>person)
    get :show,:id=>sample.id
    assert_response :forbidden
  end

  test 'anonymous cannot view' do
    person = Factory(:person)
    sample = Factory(:sample, :policy=>Factory(:private_policy), :contributor=>person)
    get :show,:id=>sample.id
    assert_response :forbidden
  end

  test 'contributor can edit' do
    person = Factory(:person)
    login_as(person)
    sample = Factory(:sample, :policy=>Factory(:private_policy), :contributor=>person)
    get :edit,:id=>sample.id
    assert_response :success
  end

  test 'non contributor cannot edit' do
    person = Factory(:person)
    other_person = Factory(:person)
    login_as(other_person)
    sample = Factory(:sample, :policy=>Factory(:private_policy), :contributor=>person)
    get :edit,:id=>sample.id
    assert_redirected_to sample
    refute_nil flash[:error]
  end

  test 'anonymous cannot edit' do
    person = Factory(:person)
    sample = Factory(:sample, :policy=>Factory(:private_policy), :contributor=>person)
    get :edit,:id=>sample.id
    assert_redirected_to sample
    refute_nil flash[:error]
  end

  test 'create with sharing' do
    person = Factory(:person)
    login_as(person)
    type = Factory(:patient_sample_type)


    assert_difference('Sample.count') do
      post :create, sample: { sample_type_id: type.id, title: 'My Sample', full_name: 'George Osborne', age: '22', weight: '22.1', postcode: 'M13 9PL', project_ids:[] },:sharing=>valid_sharing
    end
    assert sample=assigns(:sample)
    assert_equal person.user,sample.contributor
    assert_equal Policy::ALL_USERS,sample.policy.sharing_scope
    assert sample.can_view?(Factory(:person).user)
  end

  test 'update with sharing' do
    person = Factory(:person)
    other_person = Factory(:person)
    login_as(person)
    sample = populated_patient_sample
    sample.contributor=person
    sample.policy=Factory(:private_policy)
    sample.save!
    sample.reload
    refute sample.can_view?(other_person.user)

    put :update, id: sample.id, sample: { title: 'Updated Sample', full_name: 'Jesus Jones', age: '47', postcode: 'M13 9QL',project_ids:[] },:sharing=>valid_sharing

    assert sample=assigns(:sample)
    assert_equal Policy::ALL_USERS,sample.policy.sharing_scope
    assert sample.can_view?(other_person.user)
  end
  private

  def populated_patient_sample
    sample = Sample.new title: 'My Sample', policy:Factory(:public_policy), contributor:Factory(:person)
    sample.sample_type = Factory(:patient_sample_type)
    sample.title = 'My sample'
    sample.full_name = 'Fred Bloggs'
    sample.age = 22
    sample.save!
    sample
  end
end

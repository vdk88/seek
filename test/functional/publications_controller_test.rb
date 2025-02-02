require 'test_helper'

class PublicationsControllerTest < ActionController::TestCase
  fixtures :all

  include AuthenticatedTestHelper
  include RestTestCases
  include SharingFormTestHelper
  include RdfTestCases
  include MockHelper

  def setup
    login_as(Factory(:admin))
  end

  def rest_api_test_object
    @object = Factory(:publication, published_date: Date.new(2013, 1, 1))
  end

  def test_title
    get :index
    assert_select 'title', text: 'Publications', count: 1
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:publications)
  end

  test 'should get new' do
    get :new
    assert_response :success
  end

  test 'should not relate assays thay are not authorized for edit during create publication' do
    mock_pubmed(content_file: 'pubmed_1.txt')
    assay = assays(:metabolomics_assay)
    assert_difference('Publication.count') do
      post :create, params: { publication: { pubmed_id: 1, project_ids: [projects(:sysmo_project).id], assay_ids: [assay.id.to_s] } }
    end

    assert_redirected_to edit_publication_path(assigns(:publication))
    p = assigns(:publication)
    assert_equal 0, p.assays.count
  end

  test 'should create publication' do
    mock_pubmed(content_file: 'pubmed_1.txt')
    login_as(:model_owner) # can edit assay
    assay = assays(:metabolomics_assay)
    assert_difference('Publication.count') do
      post :create, params: { publication: { pubmed_id: 1, project_ids: [projects(:sysmo_project).id], assay_ids: [assay.id.to_s] } }
    end

    assert_redirected_to edit_publication_path(assigns(:publication))
    p = assigns(:publication)
    assert_equal 1, p.assays.count
    assert p.assays.include? assay
  end

  test 'should create doi publication' do
    mock_crossref(email: 'sowen@cs.man.ac.uk', doi: '10.1371/journal.pone.0004803', content_file: 'cross_ref3.xml')
    assert_difference('Publication.count') do
      post :create, params: { publication: { doi: '10.1371/journal.pone.0004803', project_ids: [projects(:sysmo_project).id] } } # 10.1371/journal.pone.0004803.g001 10.1093/nar/gkl320
    end

    assert_redirected_to edit_publication_path(assigns(:publication))
  end

  test 'should create doi publication with various doi prefixes' do
    mock_crossref(email: 'sowen@cs.man.ac.uk', doi: '10.1371/journal.pone.0004803', content_file: 'cross_ref3.xml')
    assert_difference('Publication.count') do
      post :create, params: { publication: { doi: 'DOI: 10.1371/journal.pone.0004803', project_ids: [projects(:sysmo_project).id] } } # 10.1371/journal.pone.0004803.g001 10.1093/nar/gkl320
    end

    assert_not_nil assigns(:publication)
    assert_redirected_to edit_publication_path(assigns(:publication))
    assigns(:publication).destroy

    # formatted slightly different
    assert_difference('Publication.count') do
      post :create, params: { publication: { doi: ' doi:10.1371/journal.pone.0004803', project_ids: [projects(:sysmo_project).id] } } # 10.1371/journal.pone.0004803.g001 10.1093/nar/gkl320
    end

    assert_not_nil assigns(:publication)
    assert_redirected_to edit_publication_path(assigns(:publication))
    assigns(:publication).destroy

    # with url
    assert_difference('Publication.count') do
      post :create, params: { publication: { doi: 'https://doi.org/10.1371/journal.pone.0004803', project_ids: [projects(:sysmo_project).id] } } # 10.1371/journal.pone.0004803.g001 10.1093/nar/gkl320
    end

    assert_not_nil assigns(:publication)
    assert_redirected_to edit_publication_path(assigns(:publication))
    assigns(:publication).destroy

    # with url but no protocol
    assert_difference('Publication.count') do
      post :create, params: { publication: { doi: 'doi.org/10.1371/journal.pone.0004803', project_ids: [projects(:sysmo_project).id] } } # 10.1371/journal.pone.0004803.g001 10.1093/nar/gkl320
    end

    assert_not_nil assigns(:publication)
    assert_redirected_to edit_publication_path(assigns(:publication))
    assigns(:publication).destroy

    # also test with spaces around
    assert_difference('Publication.count') do
      post :create, params: { publication: { doi: '  10.1371/journal.pone.0004803  ', project_ids: [projects(:sysmo_project).id] } } # 10.1371/journal.pone.0004803.g001 10.1093/nar/gkl320
    end

    assert_redirected_to edit_publication_path(assigns(:publication))
  end

  test 'should create publication from details' do
    publication = {
      doi: '10.1371/journal.pone.0004803',
      title: 'Clickstream Data Yields High-Resolution Maps of Science',
      abstract: 'Intricate maps of science have been created from citation data to visualize the structure of scientific activity. However, most scientific publications are now accessed online. Scholarly web portals record detailed log data at a scale that exceeds the number of all existing citations combined. Such log data is recorded immediately upon publication and keeps track of the sequences of user requests (clickstreams) that are issued by a variety of users across many different domains. Given these advantages of log datasets over citation data, we investigate whether they can produce high-resolution, more current maps of science.',
      publication_authors: ['Johan Bollen', 'Herbert Van de Sompel', 'Aric Hagberg', 'Luis Bettencourt', 'Ryan Chute', 'Marko A. Rodriguez', 'Lyudmila Balakireva'],
      journal: 'Public Library of Science (PLoS)',
      published_date: Date.new(2011, 3),
      project_ids: [projects(:sysmo_project).id]
    }

    assert_difference('Publication.count') do
      post :create, params: { subaction: 'Create', publication: publication }
    end

    assert_redirected_to edit_publication_path(assigns(:publication))
    p = assigns(:publication)

    assert_nil p.pubmed_id
    assert_equal publication[:doi], p.doi
    assert_equal publication[:title], p.title
    assert_equal publication[:abstract], p.abstract
    assert_equal publication[:journal], p.journal
    assert_equal publication[:published_date], p.published_date
    assert_equal publication[:publication_authors], p.publication_authors.collect(&:full_name)
    assert_equal publication[:project_ids], p.projects.collect(&:id)
  end

  test 'should import from bibtex file' do
    publication = {
      title: 'Taverna: a tool for building and running workflows of services.',
      journal: 'Nucleic Acids Res',
      authors: [
        PublicationAuthor.new(first_name: 'D.', last_name: 'Hull', author_index: 0),
        PublicationAuthor.new(first_name: 'K.', last_name: 'Wolstencroft', author_index: 1),
        PublicationAuthor.new(first_name: 'R.', last_name: 'Stevens', author_index: 2),
        PublicationAuthor.new(first_name: 'C.', last_name: 'Goble', author_index: 3),
        PublicationAuthor.new(first_name: 'M. R.', last_name: 'Pocock', author_index: 4),
        PublicationAuthor.new(first_name: 'P.', last_name: 'Li', author_index: 5),
        PublicationAuthor.new(first_name: 'T.', last_name: 'Oinn', author_index: 6)
      ],
      published_date: Date.new(2006)
    }
    post :create, params: { subaction: 'Import', publication: { bibtex_file: fixture_file_upload('files/publication.bibtex') } }
    p = assigns(:publication)
    assert_equal publication[:title], p.title
    assert_equal publication[:journal], p.journal
    assert_equal publication[:authors].collect(&:full_name), p.publication_authors.collect(&:full_name)
    assert_equal publication[:published_date], p.published_date
  end

  test 'should import multiple from bibtex file' do
    publications = [{
      title: 'Taverna: a tool for building and running workflows of services.',
      journal: 'Nucleic Acids Res',
      authors: [
        PublicationAuthor.new(first_name: 'D.', last_name: 'Hull', author_index: 0),
        PublicationAuthor.new(first_name: 'K.', last_name: 'Wolstencroft', author_index: 1),
        PublicationAuthor.new(first_name: 'R.', last_name: 'Stevens', author_index: 2),
        PublicationAuthor.new(first_name: 'C.', last_name: 'Goble', author_index: 3),
        PublicationAuthor.new(first_name: 'M. R.', last_name: 'Pocock', author_index: 4),
        PublicationAuthor.new(first_name: 'P.', last_name: 'Li', author_index: 5),
        PublicationAuthor.new(first_name: 'T.', last_name: 'Oinn', author_index: 6)
      ],
      published_date: Date.new(2006)
    },
                    {
                      authors: [
                        PublicationAuthor.new(first_name: 'J.', last_name: 'Shmoe', author_index: 0),
                        PublicationAuthor.new(first_name: 'M.', last_name: 'Mustermann', author_index: 1)
                      ],
                      title: 'Yet another tool for importing publications',
                      journal: 'The second best journal',
                      published_date: Date.new(2016)
                    }]

    assert_difference('Publication.count', 2) do
      post :create, params: { subaction: 'ImportMultiple', publication: { bibtex_file: fixture_file_upload('files/publications.bibtex'), project_ids: [projects(:one).id] } }
    end

    publication0 = Publication.where(title: publications[0][:title]).first
    assert_not_nil publication0
    assert_equal publications[0][:journal], publication0.journal
    assert_equal publications[0][:authors].collect(&:full_name), publication0.publication_authors.collect(&:full_name)
    assert_equal publications[0][:published_date], publication0.published_date

    publication1 = Publication.where(title: publications[1][:title]).first
    assert_not_nil publication1
    assert_equal publications[1][:journal], publication1.journal
    assert_equal publications[1][:authors].collect(&:full_name), publication1.publication_authors.collect(&:full_name)
    assert_equal publications[1][:published_date], publication1.published_date
  end

  test 'should only show the year for 1st Jan' do
    publication = Factory(:publication, published_date: Date.new(2013, 1, 1))
    get :show, params: { id: publication }
    assert_response :success
    assert_select('p') do
      assert_select 'strong', text: 'Date Published:'
      assert_select 'span', text: /2013/, count: 1
      assert_select 'span', text: /Jan.* 2013/, count: 0
    end
  end

  test 'should only show the year for 1st Jan in list view' do
    disable_authorization_checks { Publication.destroy_all }
    publication = Factory(:publication, published_date: Date.new(2013, 1, 1), title: 'blah blah blah science')
    assert_equal 1, Publication.count
    get :index
    assert_response :success

    assert_select 'div.list_item:first-of-type' do
      assert_select 'div.list_item_title a[href=?]', publication_path(publication), text: /#{publication.title}/
      assert_select 'p.list_item_attribute', text: /2013/, count: 1
      assert_select 'p.list_item_attribute', text: /Jan.* 2013/, count: 0
    end
  end

  test 'should show publication' do
    get :show, params: { id: publications(:one) }
    assert_response :success
  end

  test 'should export publication as endnote' do
    publication_formatter_mock
    with_config_value :pubmed_api_email, 'fred@email.com' do
      get :show, params: { id: publication_for_export_tests, format: 'enw' }
    end
    assert_response :success
    assert_match(/%0 Journal Article.*/, response.body)
    assert_match(/.*%A Hendrickson, W\. A\..*/, response.body)
    assert_match(/.*%A Ward, K\. B\..*/, response.body)
    assert_match(/.*%D 1975.*/, response.body)
    assert_match(/.*%T Atomic models for the polypeptide backbones of myohemerythrin and hemerythrin\..*/, response.body)
    assert_match(/.*%J Biochem Biophys Res Commun.*/, response.body)
    assert_match(/.*%V 66.*/, response.body)
    assert_match(/.*%N 4.*/, response.body)
    assert_match(/.*%P 1349-1356.*/, response.body)
    assert_match(/.*%M 5.*/, response.body)
    assert_match(/.*%U http:\/\/www.ncbi.nlm.nih.gov\/pubmed\/5.*/, response.body)
    assert_match(/.*%K Animals.*/, response.body)
    assert_match(/.*%K Cnidaria.*/, response.body)
    assert_match(/.*%K Computers.*/, response.body)
    assert_match(/.*%K \*Hemerythrin.*/, response.body)
    assert_match(/.*%K \*Metalloproteins.*/, response.body)
    assert_match(/.*%K Models, Molecular.*/, response.body)
    assert_match(/.*%K \*Muscle Proteins.*/, response.body)
    assert_match(/.*%K Protein Conformation.*/, response.body)
    assert_match(/.*%K Species Specificity.*/, response.body)
  end

  test 'should export publication as bibtex' do
    publication_formatter_mock
    with_config_value :pubmed_api_email, 'fred@email.com' do
      get :show, params: { id: publication_for_export_tests, format: 'bibtex' }
    end
    assert_response :success
    assert_match(/@article{PMID:5,.*/, response.body)
    assert_match(/.*author.*/, response.body)
    assert_match(/.*title.*/, response.body)
    assert_match(/.*journal.*/, response.body)
    assert_match(/.*year.*/, response.body)
    assert_match(/.*number.*/, response.body)
    assert_match(/.*pages.*/, response.body)
    assert_match(/.*url.*/, response.body)
  end

  test 'should export pre-print publication as bibtex' do
    publication_formatter_mock
    with_config_value :pubmed_api_email, 'fred@email.com' do
      get :show, params: { id: pre_print_publication_for_export_tests, format: 'bibtex' }
    end
    assert_response :success
    assert_match(/.*author.*/, response.body)
    assert_match(/.*title.*/, response.body)
  end

  test 'should export publication as embl' do
    publication_formatter_mock
    with_config_value :pubmed_api_email, 'fred@email.com' do
      get :show, params: { id: publication_for_export_tests, format: 'embl' }
    end
    assert_response :success
    assert_match(/RX   PUBMED; 5\..*/, response.body)
    assert_match(/.*RT   \"Atomic models for the polypeptide backbones of myohemerythrin and\nRT   hemerythrin.\";.*/, response.body)
    assert_match(/.*RA   Hendrickson W\.A\., Ward K\.B\.;.*/, response.body)
    assert_match(/.*RL   Biochem Biophys Res Commun 66\(4\):1349-1356\(1975\)\..*/, response.body)
    assert_match(/.*XX.*/, response.body)
  end

  test 'should handle bad response from efetch during export' do
    stub_request(:post, 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi')
        .with(body: { 'db' => 'pubmed', 'email' => '(fred@email.com)', 'id' => '404', 'retmode' => 'text', 'rettype' => 'medline', 'tool' => 'bioruby' },
              headers: { 'Accept' => '*/*',
                         'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                         'Content-Length' => '87',
                         'Content-Type' => 'application/x-www-form-urlencoded',
                         'User-Agent' => 'Ruby' })
        .to_return(status: 200, body: '')

    pub = Factory(:publication, title: 'A paper on blabla',
                      abstract: 'WORD ' * 20,
                      published_date: 5.days.ago.to_s(:db),
                      pubmed_id: 404)

    with_config_value :pubmed_api_email, 'fred@email.com' do
      get :show, params: { id: pub, format: 'enw' }
    end

    assert_redirected_to pub
    assert_includes flash[:error], 'There was a problem communicating with PubMed to generate the requested ENW'
  end

  test 'should handle timeout from efetch during export' do
    stub_request(:post, 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi')
        .with(body: { 'db' => 'pubmed', 'email' => '(fred@email.com)', 'id' => '999', 'retmode' => 'text', 'rettype' => 'medline', 'tool' => 'bioruby' },
              headers: { 'Accept' => '*/*',
                         'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                         'Content-Length' => '87',
                         'Content-Type' => 'application/x-www-form-urlencoded',
                         'User-Agent' => 'Ruby' })
        .to_timeout

    pub = Factory(:publication, title: 'A paper on blabla',
                  abstract: 'WORD ' * 20,
                  published_date: 5.days.ago.to_s(:db),
                  pubmed_id: 999)

    with_config_value :pubmed_api_email, 'fred@email.com' do
      get :show, params: { id: pub, format: 'enw' }
    end

    assert_redirected_to pub
    assert_includes flash[:error], 'There was a problem communicating with PubMed to generate the requested ENW'
  end

  test 'should filter publications by projects_id for export' do
    # project without publications
    get :export, params: { query: { projects_id_in: [projects(:sysmo_project).id + 1] } }
    assert_response :success
    p = assigns(:publications)
    assert_equal 0, p.length
    # project with publications
    get :export, params: { query: { projects_id_in: [projects(:sysmo_project).id] } }
    assert_response :success
    p = assigns(:publications)
    assert_equal 3, p.length
  end

  test 'should filter publications sort by published date for export' do
    # sort by published_date asc
    get :export, params: { query: { s: [{ name: :published_date, dir: :asc }] } }
    assert_response :success
    p = assigns(:publications)
    assert_operator p[0].published_date, :<=, p[1].published_date
    assert_operator p[1].published_date, :<=, p[2].published_date

    # sort by published_date desc
    get :export, params: { query: { s: [{ name: :published_date, dir: :desc }] } }
    assert_response :success
    p = assigns(:publications)
    assert_operator p[0].published_date, :>=, p[1].published_date
    assert_operator p[1].published_date, :>=, p[2].published_date
  end

  test 'should filter publications by title contains for export' do
    # sort by published_date asc
    get :export, params: { query: { title_cont: 'workflows' } }
    assert_response :success
    p = assigns(:publications)
    assert_equal 1, p.count
  end

  test 'should filter publications by authour name contains for export' do
    # sort by published_date asc
    get :export, params: { query: { publication_authors_last_name_cont: 'Bau' } }
    assert_response :success
    p = assigns(:publications)
    assert_equal 1, p.count
  end

  test 'should get edit' do
    get :edit, params: { id: publications(:one) }
    assert_response :success
  end

  test 'associates assay' do
    login_as(:model_owner) # can edit assay
    p = publications(:taverna_paper_pubmed)
    refute_nil p.contributor
    original_assay = assays(:assay_with_a_publication)
    assert p.assays.include?(original_assay)
    assert original_assay.publications.include?(p)

    new_assay = assays(:metabolomics_assay)
    assert new_assay.publications.empty?

    put :update, params: { id: p, publication: { abstract: p.abstract, assay_ids: [new_assay.id.to_s] } }

    assert_redirected_to publication_path(p)
    p.reload
    original_assay.reload
    new_assay.reload

    assert_equal 1, p.assays.count

    assert !p.assays.include?(original_assay)
    assert !original_assay.publications.include?(p)

    assert p.assays.include?(new_assay)
    assert new_assay.publications.include?(p)
  end

  test 'associates data files' do
    p = Factory(:publication)
    df = Factory(:data_file, policy: Factory(:all_sysmo_viewable_policy))
    assert !p.data_files.include?(df)
    assert !df.publications.include?(p)

    login_as(p.contributor)

    assert df.can_view?
    # add association
    put :update, params: { id: p, publication: { abstract: p.abstract, data_file_ids: [df.id.to_s] } }

    assert_redirected_to publication_path(p)
    p.reload
    df.reload

    assert_equal 1, p.data_files.count

    assert p.data_files.include?(df)
    assert df.publications.include?(p)

    # remove association
    put :update, params: { id: p, publication: { abstract: p.abstract, data_file_ids: [''] } }

    assert_redirected_to publication_path(p)
    p.reload
    df.reload

    assert_equal 0, p.data_files.count
    assert_equal 0, df.publications.count
  end

  test 'associates models' do
    p = Factory(:publication)
    model = Factory(:model, policy: Factory(:all_sysmo_viewable_policy))
    assert !p.models.include?(model)
    assert !model.publications.include?(p)

    login_as(p.contributor)
    # add association
    put :update, params: { id: p, publication: { abstract: p.abstract, model_ids: [model.id.to_s] } }

    assert_redirected_to publication_path(p)
    p.reload
    model.reload

    assert_equal 1, p.models.count
    assert_equal 1, model.publications.count

    assert p.models.include?(model)
    assert model.publications.include?(p)

    # remove association
    put :update, params: { id: p, publication: { abstract: p.abstract, model_ids: [''] } }

    assert_redirected_to publication_path(p)
    p.reload
    model.reload

    assert_equal 0, p.models.count
    assert_equal 0, model.publications.count
  end

  test 'associates investigations' do
    p = Factory(:publication)
    investigation = Factory(:investigation, policy: Factory(:all_sysmo_viewable_policy))
    assert !p.investigations.include?(investigation)
    assert !investigation.publications.include?(p)

    login_as(p.contributor)
    # add association
    put :update, params: { id: p, publication: { abstract: p.abstract, investigation_ids: [investigation.id.to_s] } }

    assert_redirected_to publication_path(p)
    p.reload
    investigation.reload

    assert_equal 1, p.investigations.count

    assert p.investigations.include?(investigation)
    assert investigation.publications.include?(p)

    # remove association
    put :update, params: { id: p, publication: { abstract: p.abstract, investigation_ids: [''] } }

    assert_redirected_to publication_path(p)
    p.reload
    investigation.reload

    assert_equal 0, p.investigations.count
    assert_equal 0, investigation.publications.count
  end

  test 'associates studies' do
    p = Factory(:publication)
    study = Factory(:study, policy: Factory(:all_sysmo_viewable_policy))
    assert !p.studies.include?(study)
    assert !study.publications.include?(p)

    login_as(p.contributor)
    # add association
    put :update, params: { id: p, publication: { abstract: p.abstract, study_ids: [study.id.to_s] } }

    assert_redirected_to publication_path(p)
    p.reload
    study.reload

    assert_equal 1, p.studies.count

    assert p.studies.include?(study)
    assert study.publications.include?(p)

    # remove association
    put :update, params: { id: p, publication: { abstract: p.abstract, study_ids: [''] } }

    assert_redirected_to publication_path(p)
    p.reload
    study.reload

    assert_equal 0, p.studies.count
    assert_equal 0, study.publications.count
  end

  test 'associates presentations' do
    p = Factory(:publication)
    presentation = Factory(:presentation, policy: Factory(:all_sysmo_viewable_policy))
    assert !p.presentations.include?(presentation)
    assert !presentation.publications.include?(p)

    login_as(p.contributor)
    # add association
    put :update, params: { id: p, publication: { abstract: p.abstract, presentation_ids:[presentation.id.to_s] } }

    assert_redirected_to publication_path(p)
    p.reload
    presentation.reload

    assert_equal 1, p.presentations.count

    assert p.presentations.include?(presentation)
    assert presentation.publications.include?(p)

    # remove association
    put :update, params: { id: p, publication: { abstract: p.abstract, presentation_ids: [''] } }

    assert_redirected_to publication_path(p)
    p.reload
    presentation.reload

    assert_equal 0, p.presentations.count
    assert_equal 0, presentation.publications.count
  end

  test 'do not associate assays unauthorized for edit' do
    p = publications(:taverna_paper_pubmed)
    original_assay = assays(:assay_with_a_publication)
    assert p.assays.include?(original_assay)
    assert original_assay.publications.include?(p)

    new_assay = assays(:metabolomics_assay)
    assert new_assay.publications.empty?

    # Should not add the new assay and should not remove the old one
    put :update, params: { id: p, publication: { abstract: p.abstract, assay_ids: [new_assay.id] } }

    assert_redirected_to publication_path(p)
    p.reload
    original_assay.reload
    new_assay.reload

    assert_equal 1, p.assays.count

    assert p.assays.include?(original_assay)
    assert original_assay.publications.include?(p)

    assert !p.assays.include?(new_assay)
    assert !new_assay.publications.include?(p)
  end

  test 'should keep model and data associations after update' do
    p = publications(:pubmed_2)
    put :update, params: { id: p, publication: { abstract: p.abstract, model_ids: p.models.collect { |m| m.id.to_s },
                                       data_file_ids: p.data_files.map(&:id), assay_ids: [''] } }

    assert_redirected_to publication_path(p)
    p.reload

    assert p.assays.empty?
    assert p.models.include?(models(:teusink))
    assert p.data_files.include?(data_files(:picture))
  end

  test 'should associate authors' do
    p = Factory(:publication, publication_authors: [Factory(:publication_author), Factory(:publication_author)])
    assert_equal 2, p.publication_authors.size
    assert_equal 0, p.creators.size

    seek_author1 = Factory(:person)
    seek_author2 = Factory(:person)

    # Associate a non-seek author to a seek person
    login_as p.contributor
    as_virtualliver do
      assert_difference('PublicationAuthor.count', 0) do
        assert_difference('AssetsCreator.count', 2) do
          put :update, params: { id: p.id, publication: {
              abstract: p.abstract,
              publication_authors_attributes: { '0' => { id: p.publication_authors[0].id, person_id: seek_author1.id },
                                                '1' => { id: p.publication_authors[1].id, person_id: seek_author2.id } } } }
        end
      end
    end
    assert_redirected_to publication_path(p)
    p.reload
  end

  test 'should disassociate authors' do
    mock_pubmed(content_file: 'pubmed_5.txt')
    p = publications(:one)
    p.publication_authors << PublicationAuthor.new(publication: p, first_name: people(:quentin_person).first_name, last_name: people(:quentin_person).last_name, person: people(:quentin_person))
    p.publication_authors << PublicationAuthor.new(publication: p, first_name: people(:aaron_person).first_name, last_name: people(:aaron_person).last_name, person: people(:aaron_person))
    p.creators << people(:quentin_person)
    p.creators << people(:aaron_person)

    assert_equal 2, p.publication_authors.size
    assert_equal 2, p.creators.size

    assert_difference('PublicationAuthor.count', 0) do
      # seek_authors (AssetsCreators) decrease by 2.
      assert_difference('AssetsCreator.count', -2) do
        post :disassociate_authors, params: { id: p.id }
      end
    end
  end

  test 'should update project' do
    p = publications(:one)
    assert_equal projects(:sysmo_project), p.projects.first
    put :update, params: { id: p.id, publication: { project_ids: [projects(:one).id] } }
    assert_redirected_to publication_path(p)
    p.reload
    assert_equal [projects(:one)], p.projects
  end

  test 'should destroy publication' do
    publication = Factory(:publication, published_date: Date.new(2013, 6, 4))

    login_as(publication.contributor)

    assert_difference('Publication.count', -1) do
      delete :destroy, params: { id: publication.id }
    end

    assert_redirected_to publications_path
  end

  test "shouldn't add paper with non-unique title within the same project" do
    mock_crossref(email: 'sowen@cs.man.ac.uk', doi: '10.1093/nar/gkl320', content_file: 'cross_ref4.xml')
    pub = Publication.find_by_doi('10.1093/nar/gkl320')

    # PubMed version of publication already exists, so it shouldn't re-add
    assert_no_difference('Publication.count') do
      post :create, params: { publication: { doi: '10.1093/nar/gkl320', projects: pub.projects.first } } if pub
    end
  end

  test 'should retrieve the right author order after a publication is created and after some authors are associate/disassociated with seek profiles' do
    mock_crossref(email: 'sowen@cs.man.ac.uk', doi: '10.1016/j.future.2011.08.004', content_file: 'cross_ref5.xml')
    assert_difference('Publication.count') do
      post :create, params: { publication: { doi: '10.1016/j.future.2011.08.004', project_ids: [projects(:sysmo_project).id] } }
    end
    publication = assigns(:publication)
    original_authors = ['Sean Bechhofer', 'Iain Buchan', 'David De Roure', 'Paolo Missier', 'John Ainsworth', 'Jiten Bhagat', 'Philip Couch', 'Don Cruickshank',
                        'Mark Delderfield', 'Ian Dunlop', 'Matthew Gamble', 'Danius Michaelides', 'Stuart Owen', 'David Newman', 'Shoaib Sufi', 'Carole Goble']

    authors = publication.publication_authors.collect { |pa| pa.first_name + ' ' + pa.last_name } # publication_authors are ordered by author_index by default
    assert_equal original_authors, authors

    seek_author1 = Factory(:person, first_name: 'Stuart', last_name: 'Owen')
    seek_author2 = Factory(:person, first_name: 'Carole', last_name: 'Goble')

    # Associate a non-seek author to a seek person
    as_virtualliver do
      assert_difference('publication.non_seek_authors.count', -2) do
        assert_difference('AssetsCreator.count', 2) do
          put :update, params: { id: publication.id, publication: {
              abstract: publication.abstract,
              publication_authors_attributes: { '0' => { id: publication.non_seek_authors[12].id, person_id: seek_author1.id },
                                                '1' => { id: publication.non_seek_authors[15].id, person_id: seek_author2.id } } } }
        end
      end
    end

    publication.reload
    authors = publication.publication_authors.map { |pa| pa.first_name + ' ' + pa.last_name }
    assert_equal original_authors, authors

    # Disassociate seek-authors
    assert_difference('publication.non_seek_authors.count', 2) do
      assert_difference('AssetsCreator.count', -2) do
        post :disassociate_authors, params: { id: publication.id }
      end
    end

    publication.reload
    authors = publication.publication_authors.map { |pa| pa.first_name + ' ' + pa.last_name }
    assert_equal original_authors, authors
  end

  test 'should display the right author order after some authors are associate with seek-profiles' do
    doi_citation_mock
    mock_crossref(email: 'sowen@cs.man.ac.uk', doi: '10.1016/j.future.2011.08.004', content_file: 'cross_ref5.xml')
    assert_difference('Publication.count') do
      post :create, params: { publication: { doi: '10.1016/j.future.2011.08.004', project_ids: [projects(:sysmo_project).id] } } # 10.1371/journal.pone.0004803.g001 10.1093/nar/gkl320
    end
    assert assigns(:publication)
    publication = assigns(:publication)
    original_authors = ['Sean Bechhofer', 'Iain Buchan', 'David De Roure', 'Paolo Missier', 'John Ainsworth', 'Jiten Bhagat', 'Philip Couch', 'Don Cruickshank',
                        'Mark Delderfield', 'Ian Dunlop', 'Matthew Gamble', 'Danius Michaelides', 'Stuart Owen', 'David Newman', 'Shoaib Sufi', 'Carole Goble']

    seek_author1 = Factory(:person, first_name: 'Stuart', last_name: 'Owen')
    seek_author2 = Factory(:person, first_name: 'Carole', last_name: 'Goble')

    # seek_authors are links
    original_authors[12] = %(<a href="/people/#{seek_author1.id}">#{publication.non_seek_authors[12].first_name + ' ' + publication.non_seek_authors[12].last_name}</a>)
    original_authors[15] = %(<a href="/people/#{seek_author2.id}">#{publication.non_seek_authors[15].first_name + ' ' + publication.non_seek_authors[15].last_name}</a>)

    # Associate a non-seek author to a seek person
    assert_difference('publication.non_seek_authors.count', -2) do
      assert_difference('AssetsCreator.count', 2) do
        put :update, params: { id: publication.id, publication: {
            abstract: publication.abstract,
            publication_authors_attributes: { '0' => { id: publication.non_seek_authors[12].id, person_id: seek_author1.id },
                                              '1' => { id: publication.non_seek_authors[15].id, person_id: seek_author2.id } } } }
      end
    end
    publication.reload
    joined_original_authors = original_authors.join(', ')
    get :show, params: { id: publication.id }
    assert @response.body.include?(joined_original_authors)
  end

  test 'should update page pagination when changing the setting from admin' do
    assert_equal 'latest', Seek::Config.default_pages[:publications]
    get :index
    assert_response :success
    assert_select '.pagination li.active' do
      assert_select 'a[href=?]', publications_path(page: 'latest')
    end

    # change the setting
    Seek::Config.default_pages[:publications] = 'all'
    get :index
    assert_response :success

    assert_select '.pagination li.active' do
      assert_select 'a[href=?]', publications_path(page: 'all')
    end
  end

  test 'should avoid XSS in association forms' do
    project = Factory(:project)
    c = Factory(:person, group_memberships: [Factory(:group_membership, work_group: Factory(:work_group, project: project))])
    Factory(:event, title: '<script>alert("xss")</script> &', projects: [project], contributor: c)
    Factory(:data_file, title: '<script>alert("xss")</script> &', projects: [project], contributor: c)
    Factory(:model, title: '<script>alert("xss")</script> &', projects: [project], contributor: c)
    i = Factory(:investigation, title: '<script>alert("xss")</script> &', projects: [project], contributor: c)
    s = Factory(:study, title: '<script>alert("xss")</script> &', investigation: i, contributor: c)
    a = Factory(:assay, title: '<script>alert("xss")</script> &', study: s, contributor: c)
    pres = Factory(:presentation, title: '<script>alert("xss")</script> &', contributor: c)
    p = Factory(:publication, projects: [project], contributor: c)

    login_as(p.contributor)

    get :edit, params: { id: p.id }

    assert_response :success
    assert_not_includes response.body, '<script>alert("xss")</script>', 'Unescaped <script> tag detected'
    # This will be slow!

    # 14 = 2 * 7 (investigations, studies, assays, events, presentations, data files and models)
    # plus an extra 4 = 2 * 2 for the study optgroups in the assay and study associations
    assert_equal 18, response.body.scan('&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt; &amp;').count
  end

  test 'programme publications through nested routing' do
    assert_routing 'programmes/2/publications', controller: 'publications', action: 'index', programme_id: '2'
    programme = Factory(:programme)
    publication = Factory(:publication, projects: programme.projects, policy: Factory(:public_policy))
    publication2 = Factory(:publication, policy: Factory(:public_policy))

    get :index, params: { programme_id: programme.id }

    assert_response :success
    assert_select 'div.list_item_title' do
      assert_select 'a[href=?]', publication_path(publication), text: publication.title
      assert_select 'a[href=?]', publication_path(publication2), text: publication2.title, count: 0
    end
  end

  test 'organism publications through nested route' do
    assert_routing 'organisms/2/publications', controller: 'publications', action: 'index', organism_id: '2'

    o1 = Factory(:organism)
    o2 = Factory(:organism)
    a1 = Factory(:assay,organisms:[o1])
    a2 = Factory(:assay,organisms:[o2])

    publication1 = Factory(:publication, assays:[a1])
    publication2 = Factory(:publication, assays:[a2])

    o1.reload
    assert_equal [publication1],o1.related_publications

    get :index, params: { organism_id: o1.id }


    assert_response :success
    assert_select 'div.list_item_title' do
      assert_select 'a[href=?]', publication_path(publication1), text: publication1.title
      assert_select 'a[href=?]', publication_path(publication2), text: publication2.title, count: 0
    end

  end

  test 'query single authors for typeahead' do
    query = 'Bloggs'
    get :query_authors_typeahead, params: { format: :json, full_name: query }
    assert_response :success
    authors = JSON.parse(@response.body)
    assert_equal 1, authors.length, authors
    assert authors[0].key?('person_id'), 'missing author person_id'
    assert authors[0].key?('first_name'), 'missing author first name'
    assert authors[0].key?('last_name'), 'missing author last name'
    assert authors[0].key?('count'), 'missing author publication count'
    assert_equal 'J', authors[0]['first_name']
    assert_equal 'Bloggs', authors[0]['last_name']
    assert_nil authors[0]['person_id']
    assert_equal 1, authors[0]['count']
  end

  test 'query single author for typeahead that is unknown' do
    query = 'Nobody knows this person'
    get :query_authors_typeahead, params: { format: :json, full_name: query }
    assert_response :success
    authors = JSON.parse(@response.body)
    assert_equal 0, authors['data'].length
  end

  test 'query authors for initialization' do
    query_authors = {
      '0' => { full_name: 'J Bloggs' },
      '1' => { full_name: 'J Bauers' }
    }
    get :query_authors, format: :json, as: :json, params: { authors: query_authors }
    assert_response :success
    authors = JSON.parse(@response.body)
    assert_equal 2, authors.length, authors
    assert authors[0].key?('person_id'), 'missing author person_id'
    assert authors[0].key?('first_name'), 'missing author first name'
    assert authors[0].key?('last_name'), 'missing author last name'
    assert authors[0].key?('count'), 'missing author publication count'
    assert_equal 'J', authors[0]['first_name']
    assert_equal 'Bloggs', authors[0]['last_name']
    assert_nil authors[0]['person_id']
    assert_equal 1, authors[0]['count']

    assert authors[1].key?('person_id'), 'missing author person_id'
    assert authors[1].key?('first_name'), 'missing author first name'
    assert authors[1].key?('last_name'), 'missing author last name'
    assert authors[1].key?('count'), 'missing author publication count'
    assert_equal 'J', authors[1]['first_name']
    assert_equal 'Bauers', authors[1]['last_name']
    assert_nil authors[1]['person_id']
    assert_equal 0, authors[1]['count']
  end

  test 'automatically extracts DOI from full DOI url' do
    project = Factory(:project)

    assert_difference('Publication.count') do
      post :create, params: { publication: { project_ids: ['', project.id.to_s],
                                   doi: 'https://doi.org/10.5072/abcd',
                                   title: 'Cool stuff',
                                   publication_authors: ['', User.current_user.person.name],
                                   abstract: 'We did stuff',
                                   journal: 'Journal of Interesting Stuff',
                                   published_date: '2017-05-23' }, subaction: 'Create' }

    end

    assert_equal '10.5072/abcd', assigns(:publication).doi
  end

  def edit_max_object(pub)
    assay = Factory(:assay, policy: Factory(:public_policy))
    study = Factory(:study, policy: Factory(:public_policy))
    inv = Factory(:investigation, policy: Factory(:public_policy))
    df = Factory(:data_file, policy: Factory(:public_policy))
    model = Factory(:model, policy: Factory(:public_policy))
    pr = Factory(:presentation, policy: Factory(:public_policy))

    pub.associate(assay)
    pub.associate(study)
    pub.associate(inv)
    pub.associate(df)
    pub.associate(model)
    pub.associate(pr)
  end

  test 'should give authors permissions' do
    person = Factory(:person)
    login_as person.user
    p = Factory(:publication, contributor: person, publication_authors: [Factory(:publication_author), Factory(:publication_author)])
    seek_author1 = Factory(:person)
    seek_author2 = Factory(:person)

    assert p.can_manage?(p.contributor.user)
    refute p.can_manage?(seek_author1.user)
    refute p.can_manage?(seek_author2.user)

    assert_difference('PublicationAuthor.count', 0) do
      assert_difference('AssetsCreator.count', 2) do
        assert_difference('Permission.count', 2) do
          put :update, params: { id: p.id, publication: {
              abstract: p.abstract,
              publication_authors_attributes: { '0' => { id: p.publication_authors[0].id, person_id: seek_author1.id },
                                                '1' => { id: p.publication_authors[1].id, person_id: seek_author2.id } } } }
        end
      end
    end

    assert_redirected_to publication_path(p)

    p = assigns(:publication)
    assert p.can_manage?(p.contributor.user)
    assert p.can_manage?(seek_author1.user)
    assert p.can_manage?(seek_author2.user)
  end

  test 'should fetch pubmed preview' do
    VCR.use_cassette('publications/fairdom_by_pubmed') do
      with_config_value :pubmed_api_email, 'fred@email.com' do
        post :fetch_preview, xhr: true, params: { key: '27899646', protocol: 'pubmed', publication: { project_ids: [User.current_user.person.projects.first.id] } }
      end
    end

    assert_response :success
    assert response.body.include?('FAIRDOMHub: a repository')
  end

  test 'should handle missing pubmed preview' do
    VCR.use_cassette('publications/missing_by_pubmed') do
      with_config_value :pubmed_api_email, 'fred@email.com' do
        post :fetch_preview, xhr: true, params: { key: '40404040404', protocol: 'pubmed', publication: { project_ids: [User.current_user.person.projects.first.id] } }
      end
    end

    assert_response :internal_server_error
    assert response.body.include?('An error has occurred')
  end

  test 'should fetch doi preview' do
    VCR.use_cassette('publications/fairdom_by_doi') do
      with_config_value :pubmed_api_email, 'fred@email.com' do
        post :fetch_preview, xhr: true, params: { key: '10.1093/nar/gkw1032', protocol: 'doi', publication: { project_ids: [User.current_user.person.projects.first.id] } }
      end
    end

    assert_response :success
    assert response.body.include?('FAIRDOMHub: a repository')
  end

  test 'should handle blank pubmed' do
    VCR.use_cassette('publications/fairdom_by_doi') do
      with_config_value :pubmed_api_email, 'fred@email.com' do
        post :fetch_preview, xhr: true, params: { key: ' ', protocol: 'pubmed', publication: { project_ids: [User.current_user.person.projects.first.id] } }
      end
    end

    assert_response :internal_server_error
    assert_match /An error has occurred.*Please enter either a DOI or a PubMed ID/,response.body
  end

  test 'should handle blank doi' do
    VCR.use_cassette('publications/fairdom_by_doi') do
      with_config_value :pubmed_api_email, 'fred@email.com' do
        post :fetch_preview, xhr: true, params: { key: ' ', protocol: 'doi', publication: { project_ids: [User.current_user.person.projects.first.id] } }
      end
    end

    assert_response :internal_server_error
    assert_match /An error has occurred.*Please enter either a DOI or a PubMed ID/,response.body
  end

  test 'should fetch doi preview with prefixes' do
    VCR.use_cassette('publications/fairdom_by_doi') do
      with_config_value :pubmed_api_email, 'fred@email.com' do
        post :fetch_preview, xhr: true, params: { key: 'doi: 10.1093/nar/gkw1032', protocol: 'doi', publication: { project_ids: [User.current_user.person.projects.first.id] } }
      end
    end

    assert_response :success
    assert response.body.include?('FAIRDOMHub: a repository')

    VCR.use_cassette('publications/fairdom_by_doi') do
      with_config_value :pubmed_api_email, 'fred@email.com' do
        post :fetch_preview, xhr: true, params: { key: 'doi.org/10.1093/nar/gkw1032', protocol: 'doi', publication: { project_ids: [User.current_user.person.projects.first.id] } }
      end
    end

    assert_response :success
    assert response.body.include?('FAIRDOMHub: a repository')

    VCR.use_cassette('publications/fairdom_by_doi') do
      with_config_value :pubmed_api_email, 'fred@email.com' do
        post :fetch_preview, xhr: true, params: { key: 'https://doi.org/10.1093/nar/gkw1032', protocol: 'doi', publication: { project_ids: [User.current_user.person.projects.first.id] } }
      end
    end

    assert_response :success
    assert response.body.include?('FAIRDOMHub: a repository')
  end

  private

  def publication_for_export_tests
    Factory(:publication, title: 'A paper on blabla',
                          abstract: 'WORD WORD WORD WORD WORD WORD WORD WORD WORD WORD WORD WORD WORD WORD WORD WORD WORD WORD',
                          published_date: 5.days.ago.to_s(:db),
                          pubmed_id: 5)
  end

  def pre_print_publication_for_export_tests
    Factory(:publication, title: 'A paper on blabla',
                          abstract: 'WORD WORD WORD WORD WORD WORD WORD WORD WORD WORD WORD WORD WORD WORD WORD WORD WORD WORD',
                          pubmed_id: nil,
                          publication_authors: [Factory(:publication_author),
                                                Factory(:publication_author)])
  end
end

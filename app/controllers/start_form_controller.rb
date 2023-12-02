# frozen_string_literal: true

class StartFormController < ApplicationController
  layout 'form'

  skip_before_action :authenticate_user!
  skip_authorization_check

  before_action :load_template

  def show
    @submitter = @template.submissions.new.submitters.new(uuid: @template.submitters.first['uuid'])
  end

  def update
    @submitter = Submitter.where(submission: @template.submissions.where(deleted_at: nil))
                          .order(id: :desc)
                          .then { |rel| params[:resubmit].present? ? rel.where(completed_at: nil) : rel }
                          .find_or_initialize_by(**submitter_params.compact_blank)

    if @submitter.completed_at?
      redirect_to start_form_completed_path(@template.slug, email: submitter_params[:email])
    else
      if @template.submitters.to_a.size > 1 && @submitter.new_record?
        @error_message = 'Not found'

        return render :show
      end

      assign_submission_attributes(@submitter, @template) if @submitter.new_record?

      if @submitter.save
        redirect_to submit_form_path(@submitter.slug)
      else
        render :show
      end
    end
  end

  def completed
    @submitter = Submitter.where(submission: @template.submissions)
                          .where.not(completed_at: nil)
                          .find_by!(email: params[:email])
  end

  private

  def assign_submission_attributes(submitter, template)
    submitter.assign_attributes(
      uuid: template.submitters.first['uuid'],
      ip: request.remote_ip,
      ua: request.user_agent,
      preferences: { 'send_email' => true }
    )

    submitter.submission ||= Submission.new(template:,
                                            template_submitters: template.submitters,
                                            source: :link)

    submitter
  end

  def submitter_params
    params.require(:submitter).permit(:email, :phone, :name).tap do |attrs|
      attrs[:email] = Submissions.normalize_email(attrs[:email])
    end
  end

  def load_template
    slug = params[:slug] || params[:start_form_slug]

    @template = Template.find_by!(slug:)
  end
end

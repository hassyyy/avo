require_dependency "avo/base_controller"

module Avo
  class AssociationsController < BaseController
    before_action :set_model, only: [:show, :index, :new, :create, :destroy]
    before_action :set_related_resource_name, only: [:show, :index, :new, :create, :destroy]
    before_action :set_related_resource, only: [:show, :index, :new, :create, :destroy]
    before_action :hydrate_related_resource, only: [:show, :index, :new, :create, :destroy]
    before_action :set_related_model, only: [:show]
    before_action :set_attachment_class, only: [:show, :index, :new, :create, :destroy]
    before_action :set_attachment_resource
    before_action :set_attachment_model, only: [:create, :destroy]
    before_action :set_reflection, only: [:index, :show]
    layout false, only: [:search]

    def index
      @parent_resource = @resource.dup
      @resource = @related_resource
      @parent_model = @parent_resource.class.find_scope.find(params[:id])
      @parent_resource.hydrate(model: @parent_model)
      @query = @authorization.apply_policy @parent_model.public_send(params[:related_name])

      super
    end

    def show
      @resource, @model = @related_resource, @related_model

      super
    end

    def new
      query = @authorization.apply_policy @attachment_class

      @options = query.all.map do |model|
        {
          value: model.id,
          label: model.send(@attachment_resource.class.title)
        }
      end
    end

    def create
      if reflection_class == "HasManyReflection"
        @model.send(params[:related_name].to_s) << @attachment_model
      else
        @model.send("#{params[:related_name]}=", @attachment_model)
      end

      respond_to do |format|
        if @model.save
          format.html { redirect_to resource_path(model: @model, resource: @resource), notice: t("avo.attachment_class_attached", attachment_class: @attachment_class) }
          format.json { render :show, status: :created, location: resource_path(model: @model, resource: @resource) }
        else
          format.html { render :new }
          format.json { render json: @model.errors, status: :unprocessable_entity }
        end
      end
    end

    def destroy
      if reflection_class == "HasManyReflection"
        @model.send(params[:related_name].to_s).delete @attachment_model
      else
        @model.send("#{params[:related_name]}=", nil)
      end

      respond_to do |format|
        format.html { redirect_to params[:referrer] || resource_path(model: @model, resource: @resource), notice: t("avo.attachment_class_detached", attachment_class: @attachment_class) }
      end
    end

    def search
      @model = @resource.model_class.find params[:id]
      @resource.hydrate model: @model
      # Try and find the appropiate field
      @field = @resource.fields.find do |field|
        # puts ['field->', field].inspect
        field.id.to_s == params[:related_name]
      end

      @field.hydrate model: @model

      @results = @field.options.map do |item|
        {
          _id: item[:value],
          _label: item[:label],
        }
      end

      render json: {
        belongs_to: {
          header: 'hey',
          results: @results
        }
      }

      # abort [@resource, @field, @field.options].inspect
      # render json: {
      #   hey: params[:q]
      # }
    end

    private

    def set_attachment_class
      @attachment_class = @model._reflections[params[:related_name].to_s].klass
    end

    def set_attachment_resource
      @attachment_resource = App.get_resource_by_model_name @attachment_class
    end

    def set_attachment_model
      @attachment_model = @model._reflections[params[:related_name].to_s].klass.find attachment_id
    end

    def set_reflection
      @reflection = @model._reflections[params[:related_name].to_s]
    end

    def attachment_id
      params[:related_id] || params.require(:fields).permit(:related_id)[:related_id]
    end

    def reflection_class
      reflection = @model._reflections[params[:related_name]]

      klass = reflection.class.name.demodulize.to_s
      klass = reflection.through_reflection.class.name.demodulize.to_s if klass == "ThroughReflection"

      klass
    end
  end
end
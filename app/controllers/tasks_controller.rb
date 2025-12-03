class TasksController < ApplicationController
  def index
    @tasks = Task.order(created_at: :desc)
  end

  def show
    @task = Task.find(params[:id])
  end

  def new
    @task = Task.new
  end

  def create
    @task = Task.new(task_params)
    if @task.save
      redirect_to root_path, notice: "Task created"
    else 
      flash.now[:alert] = "Please fix the errors below."
      render :new, status: :unprocessable_entity
    end
  end

  def edit 
    @task = Task.find(params[:id])
  end

  def update 
    @task = Task.find(params[:id])
    if @task.update(task_params)
      redirect_to root_path, notice: "Task updated"
    else
      flash.now[:alert] = "please fix the errors below."
      render :edit, status: :unprocessable_entity
    end
  end

  private 

  def task_params
    params.require(:task).permit(:title, :description, :status, :due_date)
  end
end
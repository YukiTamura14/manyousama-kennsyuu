class TasksController < ApplicationController
  before_action :require_logged_in
  before_action :set_task, only: [:show, :edit, :update, :destroy]

  def index
    # 代入
    @tasks = current_user.tasks.limit(50)

    # 検索（絞り込み。見本なのでそのまんまに書いているが、わかりづらい上にファットコントローラなのでモデルに移してリファクタすべき）
    if params[:task].present? && params[:task][:search] == "true"
      @tasks = @tasks.where("title LIKE ?", "%#{ params[:task][:title] }%") if params[:task][:title].present?
      @tasks = @tasks.where(status: params[:task][:status]) if params[:task][:status].present?
      # これがラベル検索。みづらい。
      unless params[:task][:label_id].blank? && params[:task][:label_id].to_i.zero?
        @tasks = @tasks.where(id: Labeling.where(label_id: params[:task][:label_id].to_i).pluck(:task_id))
      end
    end

    # 並び替え
    if @tasks == sort_expired?
      @tasks = @tasks.order(:expired_at)
    elsif params[:sort_priority] == "true"
      @tasks = @tasks.order(priority: "DESC")
    end

    # ページネーション
    @tasks = @tasks.page(params[:page]).per(20)
  end

  def show; end

  def new
    @task = Task.new
  end

  def edit; end

  def create
    @task = current_user.tasks.build(task_params)

    if @task.save
      if params[:task][:label_ids].present?
        # エラー対策何もできていないので一応何かしたい
        labeling_params[:label_ids].each do |label_id|
          # paramsからラベル（厳密にはTaskとLabelの中間テーブル）を複数保存する
          Labeling.create!(task_id: @task.id, label_id: label_id.to_i) unless label_id.to_i == 0
        end
      end
      redirect_to @task, notice: t("layout.task.notice_create")
    else
      render :new
    end
  end

  def update
    if @task.update(task_params)
      # ラベル関連どう考えても処理ロジックなのでモデルに移行する
      if params[:task][:label_ids].present?
        # ラベルの取り外し
        @task.labeling_labels.ids.each do |has_label_id|
          active_label = Labeling.where(task_id: @task.id).where(label_id: has_label_id).first
          # すでにそのTaskに保存されているものかつ、編集画面でチェックの外されているラベルがあったらそれの中間テーブルのレコードを削除する
          active_label.destroy! unless labeling_params[:label_ids].include?(has_label_id.to_s) || active_label.blank?
        end

        # ラベルの取り付け
        labeling_params[:label_ids].each do |label_id|
          Labeling.create!(task_id: @task.id, label_id: label_id.to_i) unless label_id.to_i == 0 || @task.labeling_labels.ids.include?(label_id.to_i)
        end
      end
      redirect_to @task, notice: t("layout.task.notice_update")
    else
      render :edit
    end
  end

  def destroy
    @task.destroy
    redirect_to tasks_url, notice: t("layout.task.notice_destroy")
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :content, :expired_at, :status)
  end

  def labeling_params
    params.require(:task).permit(label_ids: [])
  end

  def sort_expired?
    params[:sort_expired] == "true" || (params[:task].present? && params[:task][:sort_expired] == "true")
  end
end



# def escape_like(str)
#   # LIKE 句では % を \% に _ を \_ に \ を \\ にエスケープする必要がある
#   str.gsub(/\\/, "\\\\").gsub(/%/, "\\%").gsub(/_/, "\\_")
# end


# if params[:task].present? && params[:task][:search] == "true"
#   # モデルに移すべき・・・かな？
#   @tasks.where("title LIKE ?", "%#{ params[:task][:title] }%") if params[:task][:title].present?
#   @tasks.where(status: "%#{ params[:task][:status] }%") if params[:task][:status].present?
#   # さらに変な文字が来た時用
#   # Task.where("title LIKE ?", "%#{ escape_like(params[:task][:title]) }%")
# end

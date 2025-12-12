module TutorialDialogueHelper
  CHARACTERS = {
    raccoon_thinking: "https://cloud-cyo3pqn0f-hack-club-bot.vercel.app/1thinking_rac.png",
    raccoon_thumbs: "https://cloud-r04a8za6c-hack-club-bot.vercel.app/1001.png",
    raccoon_woah: "https://cloud-e9zuzn0u0-hack-club-bot.vercel.app/3003.png"
  }.freeze

  def tutorial_dialogue_config(step, context = {})
    case step
    when :create_project
      create_project_dialogue(context)
    when :setup_hackatime
      setup_hackatime_dialogue(context)
    end
  end

  private

  def create_project_dialogue(context)
    project = context[:project]
    has_time = project && project.total_hackatime_hours > 0

    if has_time
      {
        character_image: CHARACTERS[:raccoon_thumbs],
        message: "Nice work! Now post a devlog to share what you're building 🎉",
        cta_text: "Add Devlog",
        cta_href: new_project_devlog_path(project)
      }
    else
      {
        character_image: CHARACTERS[:raccoon_thinking],
        message: "Nice work! Your next step is to post a \"devlog\" - an update on your work. You probably want to hack on your project for a bit first so your devlog has some work time on it!",
        cta_text: "Got it!",
        cta_href: nil
      }
    end
  end

  def setup_hackatime_dialogue(context)
    has_time = context[:has_hackatime_time]

    if has_time
      {
        character_image: CHARACTERS[:raccoon_woah],
        message: "Whoa, you already have some coding time tracked! You're ready to create your first project.",
        cta_text: "Create Project",
        cta_href: new_project_path
      }
    else
      {
        character_image: CHARACTERS[:raccoon_thinking],
        message: "Hackatime is linked! Now start coding - your time will be tracked automatically. Once you have some work logged, come back to create your project!",
        cta_text: "Got it!",
        cta_href: nil
      }
    end
  end
end

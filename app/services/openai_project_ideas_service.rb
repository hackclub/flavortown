class OpenaiProjectIdeasService
  def self.generate
    new.generate
  end

  def generate
    prompt = build_prompt

    # If OPENAI_API_KEY isn't set
    unless ENV["OPENAI_API_KEY"].present?
      return ProjectIdea.create!(
        content: flavor("error"),
        prompt: prompt,
        model: "prompt_fallback"
      )
    end

    idea_content = OpenaiApiService.call(prompt)

    # Run formatting prompt before saving
    formatting_prompt = flavor("prompts.formatting", text: idea_content)

    formatted_idea_content = GrokApiService.call(formatting_prompt)

    project_idea = ProjectIdea.create!(
      content: formatted_idea_content,
      prompt: prompt,
      model: "gpt-4o-mini"
    )

    project_idea
  end

  private

  def build_prompt
    random_things = flavor("random_things")["array"].sample(rand(3..5)).join(", ")

    flavor("prompts.project_idea", random_things: random_things)
  end



  def message_starters
    [
      "you could build a",
      "what if you built a",
      "how about a",
      "you could make a",
      "as a dino, i think you should build a",
      "picture this:",
      "oh, oh, oh! a",
      "i dare you to make a"
    ]
  end

  def flavor(key, options = {})
    FlavortextService.project_ideas(key, options)
  end

  def fallback_idea
    content = FlavortextService.project_ideas("example_projects")
    ProjectIdea.create!(
      content: content,
      prompt: "fallback",
      model: "flavortext"
    )
  end
end

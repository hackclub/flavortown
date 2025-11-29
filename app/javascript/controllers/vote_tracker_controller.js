import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["timeField", "repoField", "demoField"]

  connect() {
    this.startTime = Date.now()
  }

  trackRepoClick() {
    console.log("Repo clicked!")
    this.repoFieldTarget.value = "true"
  }

  trackDemoClick() {
    console.log("Demo clicked!")
    this.demoFieldTarget.value = "true"
  }

  submit() {
    const endTime = Date.now()
    const durationInSeconds = Math.max(1, Math.round((endTime - this.startTime) / 1000))
    console.log(`Submitting vote. Time: ${durationInSeconds}s, Repo: ${this.repoFieldTarget.value}, Demo: ${this.demoFieldTarget.value}`)
    this.timeFieldTarget.value = durationInSeconds
  }
}

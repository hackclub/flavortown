import { Controller } from "@hotwired/stimulus";
import { init, isInitialized } from "@fullstory/browser";

export default class extends Controller {
  static targets = ["timeField", "repoField", "demoField"];
  static values = { fullstoryOrgId: String };

  connect() {
    this.startTime = Date.now();
    this.initFullStory();
  }

  initFullStory() {
    const orgId = this.fullstoryOrgIdValue;
    if (orgId && !isInitialized()) {
      init({ orgId });
    }
  }

  trackRepoClick(event) {
    if (event.type === "auxclick" && event.button === 2) {
      return;
    }
    this.repoFieldTarget.value = "true";
  }

  trackDemoClick(event) {
    if (event.type === "auxclick" && event.button === 2) {
      return;
    }
    this.demoFieldTarget.value = "true";
  }

  submit() {
    const endTime = Date.now();
    const durationInSeconds = Math.max(
      1,
      Math.round((endTime - this.startTime) / 1000),
    );
    console.log(
      `Submitting vote. Time: ${durationInSeconds}s, Repo: ${this.repoFieldTarget.value}, Demo: ${this.demoFieldTarget.value}`,
    );
    this.timeFieldTarget.value = durationInSeconds;
  }
}

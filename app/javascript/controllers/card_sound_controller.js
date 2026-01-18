import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  playSound() {
    const click = new Audio("/click.mp3");
    click.play();
  }
}

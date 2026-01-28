import { Controller } from "@hotwired/stimulus";
import { Turbo } from "@hotwired/turbo-rails";

export default class extends Controller {
  select(event) {
    const userId = event.target.value;
    const url = new URL(window.location.href);

    if (userId) {
      url.searchParams.set("view_as", userId);
    } else {
      url.searchParams.delete("view_as");
    }

    Turbo.visit(url.toString());
  }
}

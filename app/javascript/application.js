import "@hotwired/turbo-rails";
import { Turbo } from "@hotwired/turbo-rails";
import "chartkick/chart.js";
import "./controllers";
import * as ActiveStorage from "@rails/activestorage";

Turbo.session.drive = false;

ActiveStorage.start();

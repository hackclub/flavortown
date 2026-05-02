import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["output", "input"];

  async connect() {
    this.history = [];
    this.historyIndex = -1;
    this.inputTarget.disabled = true;

    this.printLine("Welcome to kernel sidequest!", "success");
    this.printLine(
      "This interactive terminal contains all the information you need.",
    );
    this.printLine("Type 'info' or 'rules' to see the sidequest requirements.");
    this.printLine("Type 'faq' to view frequently asked questions.");
    this.printLine("Type 'help' to see all available commands.");
    this.printLine("");

    this.inputTarget.disabled = false;
    this.inputTarget.focus();
    this.element.addEventListener("click", () => {
      this.inputTarget.focus();
    });
  }

  delay(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  handleKeydown(e) {
    if (e.key === "Enter") {
      e.preventDefault();
      const val = this.inputTarget.value.trim();
      this.inputTarget.value = "";
      this.processCommand(val);
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      if (this.historyIndex < this.history.length - 1) {
        this.historyIndex++;
        this.inputTarget.value =
          this.history[this.history.length - 1 - this.historyIndex];
      }
    } else if (e.key === "ArrowDown") {
      e.preventDefault();
      if (this.historyIndex > 0) {
        this.historyIndex--;
        this.inputTarget.value =
          this.history[this.history.length - 1 - this.historyIndex];
      } else if (this.historyIndex === 0) {
        this.historyIndex = -1;
        this.inputTarget.value = "";
      }
    }
  }

  processCommand(cmd, echo = true) {
    if (cmd && echo) {
      this.history.push(cmd);
      this.historyIndex = -1;
    }

    if (echo) {
      const promptLine = document.createElement("div");
      promptLine.className = "kernel-terminal__output";
      promptLine.innerHTML = `<span style="color: #22c55e"><span style="color: #3b82f6">chef@flavortown</span>:~$</span> ${cmd}`;
      this.outputTarget.appendChild(promptLine);
    }

    const args = cmd.split(" ").filter(Boolean);
    if (args.length === 0) {
      this.scrollToBottom();
      return;
    }

    const base = args[0].toLowerCase();

    switch (base) {
      case "help":
        this.printLine(
          "Available commands: help, clear, date, whoami, hack, echo, submit, info, rules, faq, ls",
        );
        break;
      case "clear":
        this.outputTarget.innerHTML = "";
        break;
      case "date":
        this.printLine(new Date().toString());
        break;
      case "whoami":
        this.printLine("chef");
        break;
      case "hack":
        this.printLine("Bypassing firewall...", "system");
        setTimeout(
          () => this.printLine("Access Denied! Nice try :)", "error"),
          500,
        );
        break;
      case "echo":
        this.printLine(args.slice(1).join(" "));
        break;
      case "faq":
        this.printLine("[ FAQ ]", "system");
        this.printLine("Q: What if I don't know how to build a CLI?");
        this.printLine(
          "A: Use a starter template or library! Search GitHub for TUI libraries.",
        );
        this.printLine("");
        this.printLine("Q: Does it have to be written in Rust/C/C++?");
        this.printLine(
          "A: No, any language is fine as long as it runs in the terminal.",
        );
        this.printLine("");
        this.printLine("Q: Can I build a web-based terminal simulator?");
        this.printLine(
          "A: Yes! Web UIs that simulate terminals are absolutely allowed and awesome (like this one!).",
        );
        break;
      case "info":
      case "rules":
        this.printLine(
          "Kernel Sidequest: Build a project that runs entirely in the terminal.",
          "success",
        );
        this.printLine("");
        this.printLine("[ REQUIREMENTS ]", "system");
        this.printLine("- Must run in the terminal (CLI / TUI / GUI).");
        this.printLine(
          "- Web UIs are allowed (basic ASCII / TUI libraries are nice).",
        );
        this.printLine(
          "- Include clear setup and run instructions in your README.",
        );
        this.printLine(
          "- Should be interactive and provide meaningful utility.",
        );
        this.printLine(
          "- Great UX (keyboard shortcuts, clean output, helpful commands).",
        );
        this.printLine("- Your project must be public on GitHub.");
        this.printLine("");
        this.printLine("[ SUBMISSION CHECKLIST ]", "system");
        this.printLine("- Public GitHub repo with source and a release/demo.");
        this.printLine("- Clear README with setup & command instructions.");
        this.printLine("- Runnable demo or downloadable artifact.");
        this.printLine("- Ship on Flavortown and submit to this sidequest.");
        this.printLine("");
        this.printLine("[ ALLOWED PROJECT TYPES ]", "system");
        this.printLine(
          "- Traditional CLI tools, Web terminal sims, Terminal games, Dashboards.",
        );
        this.printLine("");
        this.printLine("If you have questions, DM @nok on Slack.");
        this.printLine(
          "Type 'submit' to learn how to claim your prize.",
          "system",
        );
        break;
      case "submit":
        this.printLine(
          "1. Build and ship your terminal project on Flavortown.",
          "success",
        );
        this.printLine(
          "2. Click the ship button from your project page and make sure to select Kernel.",
          "success",
        );
        this.printLine(
          "3. Await approval and unlock the kernel shop prizes!",
          "success",
        );
        break;
      case "ls":
        this.printLine("README.md    main.rs    .env    src/");
        break;
      case "sudo":
        this.printLine(
          "chef is not in the sudoers file. This incident will be reported :)",
          "error",
        );
        break;
      default:
        this.printLine(`bash: ${base}: command not found`, "error");
    }

    this.scrollToBottom();
  }

  printLine(text, type = "normal") {
    const div = document.createElement("div");
    div.className = `kernel-terminal__output kernel-terminal__output--${type}`;
    div.textContent = text;
    this.outputTarget.appendChild(div);
    this.scrollToBottom();
  }

  scrollToBottom() {
    const body = this.element.querySelector(".kernel-terminal__body");
    if (body) {
      body.scrollTop = body.scrollHeight;
    }
  }
}

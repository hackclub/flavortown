class SidequestsController < ApplicationController
  def index
    # Hardcoded sidequests (legacy)
    legacy_sidequests = [
      {
        title: "The Hackazine",
        image: "nibbles/Hackazine.avif",
        sticker_image: "nibbles/Hackazine-Sticker.avif",
        description: "This January: make a page for your project and get it in the Hack Club 2025 magazine! Join #magazine and submit before January 22nd. Projects selected for the magazine receive 50 cookies + stickers! Please note, magazine submissions have 0% AI tolerance.",
        learn_more_link: "https://magazine.hackclub.com/",
        submit_link: "https://hackclub.slack.com/app_redirect?channel=C0A8CMWM0CR",
        variant: :red,
        expires_at: Date.new(2025, 1, 22)
      },
      {
        title: "Borked UI Jam",
        image: "nibbles/Borked-UI-Jam.avif",
        description: "Running until January 25th — make a project with delightfully broken UI/UX and submit it for the Borked UI Jam! The top 5 best (worst) projects will receive cookies + other prizes. Check out #borked for more details.",
        learn_more_link: "https://hackclub.slack.com/app_redirect?channel=C0A278BH8UA",
        submit_link: "https://borked.irtaza.xyz/",
        variant: :green,
        expires_at: Date.new(2025, 1, 25)
      }
    ]

    @active_sidequests = legacy_sidequests.reject { |s| s[:expires_at].present? && s[:expires_at] < Date.current }
    @expired_sidequests = legacy_sidequests.select { |s| s[:expires_at].present? && s[:expires_at] < Date.current }

    # Database-backed sidequests (for ship opt-in, not displayed as cards yet)
    @db_sidequests = Sidequest.active
  end

  def show
    @sidequest = Sidequest.find_by!(slug: params[:id])

    # if sidequest links external, redirect
    if @sidequest.external_page_link.present?
      redirect_to @sidequest.external_page_link, allow_other_host: true and return
    end

    # otherwise, render default show page
  end
end

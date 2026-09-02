# frozen_string_literal: true

module DiscoursePrivateCakeday
  # The birthdays list renders day and month only, but the column behind
  # `cakedate` is the full date of birth. Serving it verbatim would hand every
  # logged-in member the exact age of everyone on the page — the one thing the
  # user-card and post serializers go out of their way to mask.
  class BirthdayUserSerializer < CakedayUserSerializer
    def cakedate
      date = ::DiscoursePrivateCakeday.cast_date(object.cakedate)
      return date if date.blank?
      return date if scope&.is_staff? || scope&.is_me?(object)

      ::Date.new(::DiscoursePrivateCakeday::YEARLESS_SENTINEL_YEAR, date.month, date.day)
    end
  end
end

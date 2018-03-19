# coding: utf-8
# name: thrive-discourse
# about: discourse customizations for thrive community
# version: 1.0
# authors: Henri Hyyryläinen
# url: https://github.com/Revolutionary-Games/thrive-discourse

enabled_site_setting :thrive_groups_enabled

module ThriveAssignGroupPlugin
  # Updates a single user's group. Called once per day on each user (that has more than 0 posts)
  # or whenever an event is triggered that warrants re-checking (like posting)
  # user needs to be an instance of User class
  def self.verifyUserGroup(user)

    Rails.logger.debug "Verifying user group for #{user.username} (#{user.id})"

    # There doesn't seem to be a better place to do this than here
    groups = SiteSetting.thrive_groups_post_groups.split '|'
    required_posts = SiteSetting.thrive_groups_required_post_counts.split('|').map(&:to_i)
    required_times = SiteSetting.thrive_groups_required_read_time.split('|').map(&:to_i)

    # Throw if invalid settings
    if groups.length != required_posts.length || groups.length != required_times.length
      Rails.logger.error "Invalid thrive_groups settings! All the lists should be " +
                         "the same length"
      return
    end
    
    # Skip if user not part of any of the current groups (if they are in
    # a group to skip overwriting custom ones)
    if user.primary_group != nil
      begin
        primary_group = Group.find(user.primary_group_id)
      rescue ActiveRecord::RecordNotFound
        primary_group = nil
      end
    else
      primary_group = nil
    end
    
    if primary_group
      if !groups.include?(primary_group.name)
        Rails.logger.debug "Skipping user that has some weird primary group"
        return
      end
    end
    
    stats = user.user_stat

    # Perhaps newly registered?
    if stats
      users_posts = stats.post_count + stats.topic_count
      users_time_read = stats.time_read / 60
    else
      users_posts = 0
      users_time_read = 0
    end

    Rails.logger.debug "With #{users_posts} posts " +
                       "and #{users_time_read} read time"


    # Check which group they should be in
    should_be_group = nil

    for i in 0..groups.length - 1

      if users_posts < required_posts[i] || users_time_read < required_times[i]
        break
      end

      # Should be at least in this group
      should_be_group = groups[i]
    end
    
    if !should_be_group
      Rails.logger.warn "Didn't find a group for user"
      return
    end

    Rails.logger.debug "Making sure #{user.username}'s primary group " +
                       "is '#{should_be_group}'"

    if !primary_group || primary_group.name != should_be_group
      
      new_group = Group.find_by name: should_be_group

      if !new_group
        Rails.logger.error "Invalid thrive_groups settings! Group with name " +
                           "'#{should_be_group}' doesn't exist!"
        return
      end

      if primary_group
        # Remove from old group
        primary_group.remove(user)
        Rails.logger.debug "Removed user from previous group"
      end

      begin
        new_group.add(user)
      rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation
        # we don't care about this
      end          
      
      Rails.logger.debug "Updated user's group"
    end
    
  end
end

after_initialize do

  return unless SiteSetting.thrive_groups_enabled

  # Register events
  DiscourseEvent.on(:post_created){|post, opts, user|

    ThriveAssignGroupPlugin.verifyUserGroup user
  }

  DiscourseEvent.on(:user_first_logged_in){|user|

    ThriveAssignGroupPlugin.verifyUserGroup user
  }

  # This approach is partly copied from trust-level-groups plugin
  class ::Jobs::PostAmountGroupsMembership < Jobs::Scheduled

    every SiteSetting.thrive_groups_post_amount_full_verify_minutes.minute
    #every 20
    
    Rails.logger.info "PostAmountGroupsMembership full verification running every " +
                      SiteSetting.thrive_groups_post_amount_full_verify_minutes.to_s +
                      " minutes"
    
    def execute(args)

      Rails.logger.debug "Running PostAmountGroupsMembership"

      # Only process people who have posted at some point
      User.where("id > 0 AND last_posted_at IS NOT NULL").find_each do |user|
        Rails.logger.debug "Processing user '#{user.username}'"

        ThriveAssignGroupPlugin.verifyUserGroup user
      end
    end
  end
end



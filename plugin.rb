# coding: utf-8
# name: thrive-discourse
# about: discourse customizations for thrive community
# version: 1.0
# authors: Henri Hyyryläinen

enabled_site_setting :thrive_groups_enabled

# This approach is partly copied from trust-level-groups plugin
after_initialize do

  return unless SiteSetting.thrive_groups_enabled
  
  class ::Jobs::PostAmountGroupsMembership < Jobs::Scheduled

    every SiteSetting.thrive_groups_post_amount_run_every_minutes.minute
    # every SiteSetting.thrive_groups_post_amount_run_every_minutes * 10
    
    Rails.logger.info "PostAmountGroupsMembership running every " +
         SiteSetting.thrive_groups_post_amount_run_every_minutes.to_s + " minutes"
    
    def execute(args)

      groups = SiteSetting.thrive_groups_post_groups.split '|'
      required_posts = SiteSetting.thrive_groups_required_post_counts.split('|').map(&:to_i)
      required_times = SiteSetting.thrive_groups_required_read_time.split('|').map(&:to_i)

      Rails.logger.debug "Running PostAmountGroupsMembership"

      # Throw if invalid settings
      if groups.length != required_posts.length || groups.length != required_times.length
        Rails.logger.error "Invalid thrive_groups settings! All the lists should be " +
                           "the same length"
        return
      end

      # TODO: maybe loop by stats to skip just registered users?
      User.where("id > 0").find_each do |user|
        Rails.logger.debug "Processing user '#{user.username}'"

        # Skip if user not part of any of the current groups
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
          end
        end

        stats = user.user_stat

        if !stats
          next
        end

        Rails.logger.debug "With #{stats.post_count} + #{stats.topic_count} posts " +
                          "and #{stats.time_read / 60} read time"

        users_posts = stats.post_count + stats.topic_count
        users_time_read = stats.time_read / 60

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
  end
end



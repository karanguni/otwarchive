class Tag < ActiveRecord::Base

  NAME = "Tag"

  # Note: the order of this array is important.
  # It is the order that tags are shown in the header of a work
  # (banned tags are not shown)
  TYPES = ['Rating', 'Warning', 'Category', 'Media', 'Fandom', 'Relationship', 'Character', 'Freeform', 'Banned' ]

  # these tags can be filtered on
  FILTERS = TYPES - ['Banned', 'Media']

  # these tags show up on works
  VISIBLE = TYPES - ['Media', 'Banned']

  # these are tags which have been created by users
  USER_DEFINED = ['Fandom', 'Relationship', 'Character', 'Freeform']
  
  acts_as_commentable
  def commentable_name
    self.name
  end
  def commentable_owners
    if self.is_a?(Fandom)
      self.wranglers
    else
      begin
        self.fandoms.collect {|f| f.wranglers}.compact.flatten.uniq
      rescue
        []
      end
    end
  end
  
  has_many :mergers, :foreign_key => 'merger_id', :class_name => 'Tag'
  belongs_to :merger, :class_name => 'Tag'
  belongs_to :fandom
  belongs_to :media
  belongs_to :last_wrangler, :polymorphic => true
  
  has_many :filter_taggings, :foreign_key => 'filter_id', :dependent => :destroy
  has_many :filtered_works, :through => :filter_taggings, :source => :filterable, :source_type => 'Work'
  has_one :filter_count, :foreign_key => 'filter_id'
  has_many :direct_filter_taggings, 
              :class_name => "FilterTagging", 
              :foreign_key => 'filter_id', 
              :conditions => "inherited = 0"
  has_many :direct_filtered_works, :through => :direct_filter_taggings, :source => :filterable, :source_type => 'Work'

  has_many :common_taggings, :foreign_key => 'common_tag_id', :dependent => :destroy
  has_many :child_taggings, :class_name => 'CommonTagging', :as => :filterable
  has_many :children, :through => :child_taggings, :source => :common_tag 
  has_many :parents, :through => :common_taggings, :source => :filterable, :source_type => 'Tag', :before_remove => :update_wrangler

  has_many :meta_taggings, :foreign_key => 'sub_tag_id', :dependent => :destroy
  has_many :meta_tags, :through => :meta_taggings, :source => :meta_tag, :before_remove => :remove_meta_filters
  has_many :sub_taggings, :class_name => 'MetaTagging', :foreign_key => 'meta_tag_id', :dependent => :destroy
  has_many :sub_tags, :through => :sub_taggings, :source => :sub_tag, :before_remove => :remove_sub_filters
  has_many :direct_meta_tags, :through => :meta_taggings, :source => :meta_tag, :conditions => "meta_taggings.direct = 1"
  has_many :direct_sub_tags, :through => :sub_taggings, :source => :sub_tag, :conditions => "meta_taggings.direct = 1"
  
  has_many :same_work_tags, :through => :works, :source => :tags, :uniq => true
  has_many :suggested_fandoms, :through => :works, :source => :fandoms, :uniq => true

  has_many :taggings, :as => :tagger
  has_many :works, :through => :taggings, :source => :taggable, :source_type => 'Work'
  has_many :bookmarks, :through => :taggings, :source => :taggable, :source_type => 'Bookmark'
  has_many :external_works, :through => :taggings, :source => :taggable, :source_type => 'ExternalWork'
  has_many :approved_collections, :through => :filtered_works

  has_many :set_taggings, :dependent => :destroy

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_length_of :name, :minimum => 1, :message => "cannot be blank."
  validates_length_of :name,
    :maximum => ArchiveConfig.TAG_MAX,
    :message => "of tag is too long -- try using less than #{ArchiveConfig.TAG_MAX} characters or using commas to separate your tags."
  validates_format_of :name,
    :with => /\A[^,*<>^{}=`\\%]+\z/,
    :message => 'of a tag can not include the following restricted characters: , ^ * < > { } = ` \\ %'

  before_validation :check_synonym
  def check_synonym
    if !self.new_record? && self.name_changed?
      unless User.current_user.is_a?(Admin) || (self.name.downcase == self.name_was.downcase)
        self.errors.add(:name, "can only be changed by an admin.")        
      end
    end
    if self.merger_id
      if self.canonical?
        self.errors.add(:base, "A canonical can't be a synonym")       
      end 
      if self.merger_id == self.id
        self.errors.add(:base, "A tag can't be a synonym of itself.")
      end
      unless self.merger.class == self.class
        self.errors.add(:base, "A tag can only be a synonym of a tag in the same category as itself.")        
      end
    end    
  end

  before_validation :squish_name
  def squish_name
    self.name = name.squish if self.name
  end
  
  before_save :set_last_wrangler
  def set_last_wrangler
    unless User.current_user.nil?
      self.last_wrangler = User.current_user
    end
  end
  def update_wrangler(tag)
    unless User.current_user.nil?
      self.update_attributes(:last_wrangler => User.current_user)
    end
  end

  scope :id_only, select("tags.id")

  scope :canonical, where(:canonical => true).order('name ASC')
  scope :noncanonical, where(:canonical => false).order('name ASC')
  scope :nonsynonymous, noncanonical.where(:merger_id => nil)
  scope :unfilterable, nonsynonymous
  
  # we need to manually specify a LEFT JOIN instead of just joins(:common_taggings or :meta_taggings) here because
  # what we actually need are the empty rows in the results
  scope :unwrangled, joins("LEFT JOIN `common_taggings` ON common_taggings.common_tag_id = tags.id").where("common_taggings.id IS NULL")
  scope :first_class, joins("LEFT JOIN `meta_taggings` ON meta_taggings.sub_tag_id = tags.id").where("meta_taggings.id IS NULL")
  
  # Tags that have sub tags
  scope :meta_tag, joins(:sub_taggings).where("meta_taggings.id IS NOT NULL").group("tags.id")
  # Tags that don't have sub tags
  scope :non_meta_tag, joins(:sub_taggings).where("meta_taggings.id IS NULL").group("tags.id")
  
  
  # Complicated query alert!
  # What we're doing here:
  # - we get all the tags of any type used on works (the first two lines of the join)
  # - we then chop that down to only the tags used on works that are tagged with our one given tag 
  #   (the last line of the join, and the where clause)
  scope :related_tags_for_all, lambda {|tags|
    joins("INNER JOIN taggings ON (tags.id = taggings.tagger_id)
           INNER JOIN works ON (taggings.taggable_id = works.id AND taggings.taggable_type = 'Work') 
           INNER JOIN taggings taggings2 ON (works.id = taggings2.taggable_id AND taggings2.taggable_type = 'Work')").
    where("taggings2.tagger_id IN (?)", tags.collect(&:id)).
    group("tags.id")
  }
  
  scope :related_tags, lambda {|tag| related_tags_for_all([tag])}
  
  scope :by_popularity, order('taggings_count DESC')
  scope :by_name, order('name ASC')
  scope :by_date, order('created_at DESC')
  scope :visible, where('type in (?)', VISIBLE).by_name

  scope :by_pseud, lambda {|pseud|
    joins(:works => :pseuds).
    where(:pseuds => {:id => pseud.id})
  }

  scope :by_type, lambda {|*types| where(types.first.blank? ? "" : {:type => types.first})}
  scope :with_type, lambda {|type| where({:type => type}) }

  # This will return all tags that have one of the given tags as a parent
  scope :with_parents, lambda {|parents|
    joins(:common_taggings).where("filterable_id in (?)", parents.collect(&:id).join(","))
  }

  scope :starting_with, lambda {|letter| where('SUBSTR(name,1,1) = ?', letter)}

  scope :filters_with_count, lambda { |work_ids|
    select("tags.*, count(distinct works.id) as count").
    joins(:filtered_works).
    where("works.id IN (?)", work_ids).
    order(:name).
    group(:id)
  }
  
  scope :visible_to_all_with_count,
    joins(:filter_count).
    select("tags.*, filter_counts.public_works_count as count").
    where('filter_counts.public_works_count > 0 AND tags.canonical = 1')
    
  scope :visible_to_registered_user_with_count,
    joins(:filter_count).
    select("tags.*, filter_counts.unhidden_works_count as count").
    where('filter_counts.unhidden_works_count > 0 AND tags.canonical = 1')
    
  scope :public_top, lambda { |tag_count|
    visible_to_all_with_count.
    limit(tag_count).
    order('filter_counts.public_works_count DESC')
  }
  
  scope :unhidden_top, lambda { |tag_count|
    visible_to_registered_user_with_count.
    limit(tag_count).
    order('filter_counts.unhidden_works_count DESC')
  }
  
  scope :popular, (User.current_user.is_a?(Admin) || User.current_user.is_a?(User)) ? 
      visible_to_registered_user_with_count.order('filter_counts.unhidden_works_count DESC') : 
      visible_to_all_with_count.order('filter_counts.public_works_count DESC')
      
  scope :random, (User.current_user.is_a?(Admin) || User.current_user.is_a?(User)) ? 
    visible_to_registered_user_with_count.order("RAND()") : 
    visible_to_all_with_count.order("RAND()")
  
  scope :with_count, (User.current_user.is_a?(Admin) || User.current_user.is_a?(User)) ? 
      visible_to_registered_user_with_count : visible_to_all_with_count

  # a complicated join -- we only want to get the tags on approved, posted works in the collection
  COLLECTION_JOIN =  "INNER JOIN filter_taggings ON ( tags.id = filter_taggings.filter_id ) 
                      INNER JOIN works ON ( filter_taggings.filterable_id = works.id AND filter_taggings.filterable_type = 'Work') 
                      INNER JOIN collection_items ON ( works.id = collection_items.item_id AND collection_items.item_type = 'Work'
                                                       AND works.posted = 1
                                                       AND collection_items.collection_approval_status = '#{CollectionItem::APPROVED}'
                                                       AND collection_items.user_approval_status = '#{CollectionItem::APPROVED}' ) " 

  scope :for_collections, lambda {|collections|
    joins(COLLECTION_JOIN).
    where("collection_items.collection_id IN (?)", collections.collect(&:id))
  }

  scope :for_collection, lambda { |collection| for_collections([collection]) }
  
  scope :for_collections_with_count, lambda { |collections| 
    for_collections(collections).
    select("tags.*, count(tags.id) as count").
    group(:id).
    order(:name)
  }
  
  scope :by_relationships, lambda {|relationships| 
    select("DISTINCT tags.*").
    joins(:children).
    where('children_tags.id IN (?)', relationships.collect(&:id))
  }
  
  scope :in_challenge, lambda {|collection|
    joins("INNER JOIN set_taggings ON (tags.id = set_taggings.tag_id) 
           INNER JOIN tag_sets ON (set_taggings.tag_set_id = tag_sets.id)
           INNER JOIN prompts ON (prompts.tag_set_id = tag_sets.id OR prompts.optional_tag_set_id = tag_sets.id)
           INNER JOIN challenge_signups ON (prompts.challenge_signup_id = challenge_signups.id)").
    where("challenge_signups.collection_id = ?", collection.id)
  }
  
  scope :requested_in_challenge, lambda {|collection|
    in_challenge(collection).where("prompts.type = 'Request'")
  }
  
  scope :offered_in_challenge, lambda {|collection|
    in_challenge(collection).where("prompts.type = 'Offer'")
  }

      
  # Class methods


  # Get tags that are either above or below the average popularity 
  def self.with_popularity_relative_to_average(options = {:factor => 1, :include_meta => false, :greater_than => false, :names_only => false})
    comparison = "<"
    comparison = ">" if options[:greater_than]
      
    if options[:include_meta]
      tags = select("#{options[:names_only] ? "tags.name" : "tags.*"}, filter_counts.unhidden_works_count as count").
                  joins(:filter_count).
                  where(:canonical => true).
                  where("filter_counts.unhidden_works_count #{comparison} (select avg(unhidden_works_count) from filter_counts) * ?", options[:factor]).
                  order("count ASC")
    else
      meta_tag_ids = select("DISTINCT tags.id").joins(:sub_taggings).where(:canonical => true)
      non_meta_ids = meta_tag_ids.empty? ? select("tags.id").where(:canonical => true) : select("tags.id").where(:canonical => true).where("id NOT IN (#{meta_tag_ids.collect(&:id).join(',')})")
      tags = non_meta_ids.empty? ? [] : 
                select("#{options[:names_only] ? "tags.name" : "tags.*"}, filter_counts.unhidden_works_count as count").
                  joins(:filter_count).
                  where(:canonical => true).
                  where("tags.id IN (#{non_meta_ids.collect(&:id).join(',')})").
                  where("filter_counts.unhidden_works_count #{comparison} (select AVG(unhidden_works_count) from filter_counts where filter_id in (#{non_meta_ids.collect(&:id).join(',')})) * ?", options[:factor]).
                  order("count ASC")
    end
  end
  
  # Used for associations, such as work.fandoms.string
  # Yields a comma-separated list of tag names
  def self.string
    all.map{|tag| tag.name}.join(ArchiveConfig.DELIMITER_FOR_OUTPUT)
  end  

  # Use the tag name in urls and escape url-unfriendly characters
  def to_param
    # can't find a tag with a name that hasn't been saved yet
    saved_name = self.name_changed? ? self.name_was : self.name
    saved_name.gsub('/', '%2F').gsub('&', '%26').gsub('.', '%2E').gsub('?', '%3F')
  end
  
  # Substitute characters that are particularly prone to cause trouble in urls
  def self.find_by_name(string)
    self.find(:first, :conditions => ['name = ?', string.gsub('%2F', '/').gsub('%26', '&').gsub('%2F', '/').gsub('%2E', '.').gsub('%3F', '?')]) if string
  end
  
  # If a tag by this name exists in another class, add a suffix to disambiguate them
  def self.find_or_create_by_name(new_name)
    if new_name && new_name.is_a?(String)
      new_name.squish!
      tag = Tag.find_by_name(new_name)
      if tag && tag.class == self
        tag
      elsif tag
        self.find_or_create_by_name(new_name + " - " + self.to_s)
      else
        self.create(:name => new_name)
      end
    end
  end

  def self.create_canonical(name, adult=false)
    tag = self.find_or_create_by_name(name)
    raise "how did this happen?" unless tag
    tag.update_attribute(:canonical,true)
    tag.update_attribute(:adult, adult)
    raise "how did this happen?" unless tag.canonical?
    return tag
  end
  
  # Inherited tag classes can set this to indicate types of tags with which they may have a parent/child
  # relationship (ie. media: parent, fandom: child; fandom: parent, character: child)
  def parent_types
    []
  end
  def child_types
    []
  end

  # Instance methods that are common to all subclasses (may be overridden in the subclass)
  
  def unwrangled?
    !self.canonical && !self.merger_id && self.mergers.empty?  
  end

  # sort tags by name
  def <=>(another_tag)
    name.downcase <=> another_tag.name.downcase
  end
  
  #### FILTERING ####

  # Add any filter taggings that should exist but don't
  def self.add_missing_filter_taggings
    Tag.find_each(:conditions => "taggings_count != 0 AND (canonical = 1 OR merger_id IS NOT NULL)") do |tag|
      if tag.filter
        to_add = tag.works - tag.filter.filtered_works
        to_add.each do |work|
          tag.filter.filter_taggings.create!(:filterable => work)
        end
      end
    end
  end
  
  # Add any filter taggings that should exist but don't
  def self.add_missing_filter_taggings
    i = Work.posted.count
    Work.find_each(:conditions => "posted = 1") do |work|
      begin
        should_have = work.tags.collect(&:filter).compact.uniq
        should_add = should_have - work.filters
        unless should_add.empty?
          puts "Fixing work #{i}"
          work.filters = (work.filters + should_add).uniq
        end
      rescue
        puts "Problem with work #{work.id}"
      end
      i = i - 1
    end
  end 
  
  # The version of the tag that should be used for filtering, if any
  def filter
    self.canonical? ? self : ((self.merger && self.merger.canonical?) ? self.merger : nil)
  end

  before_save :update_filters_for_canonical_change
  before_save :update_filters_for_merger_change
  
  # If a tag was not canonical but is now, it needs new filter_taggings
  # If it was canonical but isn't anymore, we need to change or remove
  # the filter_taggings as appropriate
  def update_filters_for_canonical_change
    if self.canonical_changed?
      if self.canonical?
        self.add_filter_taggings
      elsif self.merger && self.merger.canonical?
        self.filter_taggings.update_all(["filter_id = ?", self.merger_id])
        self.reset_filter_count
      else
        self.remove_filter_taggings
      end
    end      
  end
  
  # If a tag has a new merger, add to the filter_taggings for that merger
  # If a tag has a new merger but had an old merger, add new filter_taggings
  # and get rid of the old filter_taggings as appropriate 
  def update_filters_for_merger_change
    if self.merger_id_changed?
      if self.merger && self.merger.canonical?
        self.add_filter_taggings
      end
      old_merger = Tag.find_by_id(self.merger_id_was)
      if old_merger && old_merger.canonical?
        self.remove_filter_taggings(old_merger)
      end
    end  
  end
  
  # Add filter taggings for a given tag
  def add_filter_taggings
    filter_tag = self.filter
    if filter_tag  && !filter_tag.new_record?
      Work.with_any_tags([self, filter_tag]).each do |work|
        work.filters << filter_tag unless work.filters.include?(filter_tag)
        unless filter_tag.meta_tags.empty?
          filter_tag.meta_tags.each do |m| 
            unless work.filters.include?(m)
              work.filter_taggings.create!(:inherited => true, :filter_id => m.id)
            end
          end
        end
      end
      filter.reset_filter_count
    end
  end
  
  # Remove filter taggings for a given tag
  # If an old_filter value is given, remove filter_taggings from it with due regard
  # for potential duplication (ie, works tagged with more than one synonymous tag)
  def remove_filter_taggings(old_filter=nil)
    if old_filter
      potential_duplicate_filters = [old_filter] + old_filter.mergers - [self]
      self.works.each do |work|
        if (work.tags & potential_duplicate_filters).empty?
          filter_tagging = work.filter_taggings.find_by_filter_id(old_filter.id)
          filter_tagging.destroy if filter_tagging
        end
        unless old_filter.meta_tags.empty?
          old_filter.meta_tags.each do |meta_tag|
            other_sub_tags = meta_tag.sub_tags - [old_filter]
            sub_mergers = other_sub_tags.empty? ? [] : other_sub_tags.collect(&:mergers).flatten.compact
            if work.filters.include?(meta_tag) && (work.filters & other_sub_tags).empty?
              unless work.tags.include?(meta_tag) || !(work.tags & meta_tag.mergers).empty? || !(work.tags & sub_mergers).empty?
                work.filters.delete(meta_tag)
              end
            end
          end
        end        
      end      
      old_filter.reset_filter_count      
    else
      self.filter_taggings.destroy_all
      self.reset_filter_count
    end   
  end
  
  def reset_filter_count
    current_filter = self.filter
    # we only need to cache values for user-defined tags
    # because they're the only ones we access
    if current_filter && (Tag::USER_DEFINED.include?(current_filter.class.to_s))
      attributes = {:public_works_count => current_filter.filtered_works.posted.unhidden.unrestricted.count, 
                    :unhidden_works_count => current_filter.filtered_works.posted.unhidden.count}
      if current_filter.filter_count
        unless current_filter.filter_count.update_attributes(attributes)
          raise "Filter count error for #{current_filter.name}"
        end        
      else
        unless current_filter.create_filter_count(attributes)
          raise "Filter count error for #{current_filter.name}"
        end
      end
    end
  end
  
  #### END FILTERING ####

  # methods for counting visible
  
  def visible_works_count
    User.current_user.nil? ? self.works.posted.unhidden.unrestricted.count : self.works.posted.unhidden.count 
  end

  def visible_bookmarks_count
    self.bookmarks.public.count
  end

  def visible_external_works_count
    self.external_works.count(:all, :conditions => {:hidden_by_admin => false})
  end

  def visible_taggables_count
    visible_works_count + visible_bookmarks_count + visible_external_works_count
  end

  def banned
    self.is_a?(Banned)
  end
  
  def synonyms
    self.canonical? ? self.mergers : [self.merger] + self.merger.mergers - [self]
  end
  
  # Add a common tagging association
  # Offloading most of the logic to the inherited tag models
  def add_association(tag)
    self.parents << tag unless self.parents.include?(tag)    
  end
  
  # Determine how two tags are related and divorce them from each other
  def remove_association(tag)
    if tag.class == self.class
      if self.mergers.include?(tag)
        tag.update_attributes(:merger_id => nil)
      elsif self.meta_tags.include?(tag)
        self.meta_tags.delete(tag)
      elsif self.sub_tags.include?(tag)
        tag.meta_tags.delete(self)
      end
    else
      if self.parents.include?(tag)
        self.parents.delete(tag)
      elsif tag.parents.include?(self)
        tag.parents.delete(self)
      end
    end    
  end
  
  # When a meta tagging relationship is removed, things filter-tagged with the meta tag 
  # and the sub tag should have the meta filter-tagging removed unless it's directly tagged 
  # with the meta tag or one of its synonyms or a different sub tag of the meta tag or one of its synonyms
  def remove_meta_filters(meta_tag) 
    # remove meta tag from this tag's sub tags 
    self.sub_tags.each {|sub| sub.meta_tags.delete(meta_tag) if sub.meta_tags.include?(meta_tag)}
    # remove inherited meta tags from this tag and all of its sub tags
    inherited_meta_tags = meta_tag.meta_tags
    inherited_meta_tags.each do |tag| 
      self.meta_tags.delete(tag) if self.meta_tags.include?(tag)
      self.sub_tags.each {|sub| sub.meta_tags.delete(tag) if sub.meta_tags.include?(tag)}
    end
    # remove filters for meta tag from this tag's works
    other_sub_tags = meta_tag.sub_tags - ([self] + self.sub_tags)
    self.filtered_works.each do |work|
      to_remove = [meta_tag] + inherited_meta_tags
      to_remove.each do |tag|
        if work.filters.include?(tag) && (work.filters & other_sub_tags).empty?
          unless work.tags.include?(tag) || !(work.tags & tag.mergers).empty?
            work.filters.delete(tag)
          end
        end
      end
    end
  end
  
  def remove_sub_filters(sub_tag)
    sub_tag.remove_meta_filters(self)
  end
  
  # If we're making a tag non-canonical, we need to update its synonyms and children
  before_update :check_canonical
  def check_canonical
    if self.canonical_changed? && !self.canonical?
      self.mergers.each {|tag| tag.update_attributes(:merger_id => nil) if tag.merger_id == self.id }
      self.children.each {|tag| tag.parents.delete(self) if tag.parents.include?(self) }
      self.sub_tags.each {|tag| tag.meta_tags.delete(self) if tag.meta_tags.include?(self) }
      self.meta_tags.each {|tag| self.meta_tags.delete(tag) if self.meta_tags.include?(tag) }
    elsif self.canonical_changed? && self.canonical?
      self.merger_id = nil
    end
    true
  end
  
  attr_reader :media_string, :fandom_string, :character_string, :relationship_string, :freeform_string, :meta_tag_string, :sub_tag_string, :merger_string
  
  def add_parent_string(tag_string)
    names = tag_string.split(',').map(&:squish)
    names.each do |name|
      parent = Tag.find_by_name(name)
      self.add_association(parent) if parent && parent.canonical?
    end   
  end
  
  def fandom_string=(tag_string); self.add_parent_string(tag_string); end
  def media_string=(tag_string); self.add_parent_string(tag_string); end
  def character_string=(tag_string); self.add_parent_string(tag_string); end
  def relationship_string=(tag_string); self.add_parent_string(tag_string); end
  def freeform_string=(tag_string); self.add_parent_string(tag_string); end
  def meta_tag_string=(tag_string)
    names = tag_string.split(',').map(&:squish)
    names.each do |name|
      parent = self.class.find_by_name(name)
      if parent
        meta_tagging = self.meta_taggings.build(:meta_tag => parent, :direct => true)
        unless meta_tagging.valid? && meta_tagging.save
          self.errors.add(:base, "You attempted to create an invalid meta tagging. :(")
        end
      end
    end
  end
  
  def sub_tag_string=(tag_string)
    names = tag_string.split(',').map(&:squish)
    names.each do |name|
      sub = self.class.find_by_name(name)
      if sub
        meta_tagging = sub.meta_taggings.build(:meta_tag => self, :direct => true)
        unless meta_tagging.valid? && meta_tagging.save
          self.errors.add(:base, "You attempted to create an invalid meta tagging. :(")
        end
      end
    end
  end
  
  def syn_string
    self.merger.name if self.merger
  end
  
  def syn_string=(tag_string)
    if tag_string.blank?
      self.merger_id = nil
    else
      new_merger = Tag.find_by_name(tag_string)
      unless new_merger && new_merger == self.merger
        if new_merger && new_merger == self
          self.errors.add(:base, tag_string + " is considered the same as " + self.name + " by the database.")
        elsif new_merger && !new_merger.canonical?
          self.errors.add(:base, new_merger.name + " is not a canonical tag. Please make it canonical before adding synonyms to it.")
        elsif new_merger && new_merger.class != self.class
          self.errors.add(:base, new_merger.name + " is a #{new_merger.type.to_s.downcase}. Synonyms must belong to the same category.")
        elsif !new_merger
          new_merger = self.class.new(:name => tag_string, :canonical => true)
          unless new_merger.save
            self.errors.add(:base, tag_string + " could not be saved. Please make sure that it's a valid tag name.")
          end
        end
        if new_merger && self.errors.empty?
          self.canonical = false      
          self.merger_id = new_merger.id
          ((self.parents + self.children) - (new_merger.parents + new_merger.children)).each { |tag| new_merger.add_association(tag) }
          if new_merger.is_a?(Fandom)
            (new_merger.medias - self.medias).each {|medium| self.add_association(medium)}
          else
            (new_merger.parents.by_type("Fandom").canonical - self.fandoms).each {|fandom| self.add_association(fandom)}
          end
          self.meta_tags.each { |tag| new_merger.meta_tags << tag unless new_merger.meta_tags.include?(tag) }
          self.sub_tags.each { |tag| tag.meta_tags << new_merger unless tag.meta_tags.include?(new_merger) }            
          self.mergers.each {|m| m.update_attributes(:merger_id => new_merger.id)}
          self.children = []
          self.meta_tags = []
          self.sub_tags = []        
        end    
      end
    end
  end
  
  def merger_string=(tag_string)
    names = tag_string.split(',').map(&:squish)
    names.each do |name|
      syn = Tag.find_by_name(name)
      if syn && !syn.canonical?
        syn.update_attributes(:merger_id => self.id)
        if syn.is_a?(Fandom)
          syn.medias.each {|medium| self.add_association(medium)}
          self.medias.each {|medium| syn.add_association(medium)}
        else
          syn.parents.by_type("Fandom").canonical.each {|fandom| self.add_association(fandom)}
          self.parents.by_type("Fandom").canonical.each {|fandom| syn.add_association(fandom)}
        end
      end
    end          
  end

  def indirect_bookmarks(rec=false)
    cond = rec ? {:rec => true, :private => false, :hidden_by_admin => false} : {:private => false, :hidden_by_admin => false}
    work_bookmarks = Bookmark.find(:all, :conditions => {:bookmarkable_id => self.work_ids, :bookmarkable_type => 'Work'}.merge(cond))
    ext_work_bookmarks = Bookmark.find(:all, :conditions => {:bookmarkable_id => self.external_work_ids, :bookmarkable_type => 'ExternalWork'}.merge(cond))
    series_bookmarks = [] # can't tag a series directly? # Bookmark.find(:all, :conditions => {:bookmarkable_id => self.series_ids, :bookmarkable_type => 'Series'}.merge(cond))
    (work_bookmarks + ext_work_bookmarks + series_bookmarks)
  end

  # Index for Thinking Sphinx
  define_index do

    # fields
    indexes :name, :sortable => true
    indexes :type, :sortable => true
    has canonical

    # properties
    set_property :delta => :delayed
  end

end

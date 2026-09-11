export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      admin_audit_logs: {
        Row: {
          action: string
          admin_user_id: string
          created_at: string
          id: number
          metadata: Json
          reason: string | null
          target_id: string | null
          target_type: string
        }
        Insert: {
          action: string
          admin_user_id: string
          created_at?: string
          id?: never
          metadata?: Json
          reason?: string | null
          target_id?: string | null
          target_type: string
        }
        Update: {
          action?: string
          admin_user_id?: string
          created_at?: string
          id?: never
          metadata?: Json
          reason?: string | null
          target_id?: string | null
          target_type?: string
        }
        Relationships: []
      }
      audit_events: {
        Row: {
          actor_type: Database["public"]["Enums"]["audit_actor_type"]
          actor_user_id: string | null
          after_data: Json | null
          before_data: Json | null
          created_at: string
          entity_id: string | null
          entity_type: string
          event_type: string
          household_id: string
          id: number
          metadata: Json
        }
        Insert: {
          actor_type?: Database["public"]["Enums"]["audit_actor_type"]
          actor_user_id?: string | null
          after_data?: Json | null
          before_data?: Json | null
          created_at?: string
          entity_id?: string | null
          entity_type: string
          event_type: string
          household_id: string
          id?: never
          metadata?: Json
        }
        Update: {
          actor_type?: Database["public"]["Enums"]["audit_actor_type"]
          actor_user_id?: string | null
          after_data?: Json | null
          before_data?: Json | null
          created_at?: string
          entity_id?: string | null
          entity_type?: string
          event_type?: string
          household_id?: string
          id?: never
          metadata?: Json
        }
        Relationships: [
          {
            foreignKeyName: "audit_events_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      budget_periods: {
        Row: {
          closed_at: string | null
          created_at: string
          created_by: string
          end_date: string
          household_id: string
          id: string
          opened_at: string | null
          period_key: string
          spending_budget: number
          start_date: string
          status: Database["public"]["Enums"]["period_status"]
          updated_at: string
        }
        Insert: {
          closed_at?: string | null
          created_at?: string
          created_by: string
          end_date: string
          household_id: string
          id?: string
          opened_at?: string | null
          period_key: string
          spending_budget?: number
          start_date: string
          status?: Database["public"]["Enums"]["period_status"]
          updated_at?: string
        }
        Update: {
          closed_at?: string | null
          created_at?: string
          created_by?: string
          end_date?: string
          household_id?: string
          id?: string
          opened_at?: string | null
          period_key?: string
          spending_budget?: number
          start_date?: string
          status?: Database["public"]["Enums"]["period_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "budget_periods_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      budget_sections: {
        Row: {
          archived_at: string | null
          created_at: string
          created_by: string
          default_planned_amount: number
          household_id: string
          id: string
          is_active: boolean
          kind: Database["public"]["Enums"]["section_kind"]
          member_access: Database["public"]["Enums"]["section_member_access"]
          name: string
          sort_order: number
          updated_at: string
          visibility_scope: Database["public"]["Enums"]["visibility_scope"]
        }
        Insert: {
          archived_at?: string | null
          created_at?: string
          created_by: string
          default_planned_amount?: number
          household_id: string
          id?: string
          is_active?: boolean
          kind: Database["public"]["Enums"]["section_kind"]
          member_access?: Database["public"]["Enums"]["section_member_access"]
          name: string
          sort_order?: number
          updated_at?: string
          visibility_scope?: Database["public"]["Enums"]["visibility_scope"]
        }
        Update: {
          archived_at?: string | null
          created_at?: string
          created_by?: string
          default_planned_amount?: number
          household_id?: string
          id?: string
          is_active?: boolean
          kind?: Database["public"]["Enums"]["section_kind"]
          member_access?: Database["public"]["Enums"]["section_member_access"]
          name?: string
          sort_order?: number
          updated_at?: string
          visibility_scope?: Database["public"]["Enums"]["visibility_scope"]
        }
        Relationships: [
          {
            foreignKeyName: "budget_sections_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      fixed_commitment_templates: {
        Row: {
          archived_at: string | null
          created_at: string
          created_by: string
          default_amount: number
          due_day: number | null
          household_id: string
          id: string
          is_active: boolean
          name: string
          updated_at: string
        }
        Insert: {
          archived_at?: string | null
          created_at?: string
          created_by: string
          default_amount?: number
          due_day?: number | null
          household_id: string
          id?: string
          is_active?: boolean
          name: string
          updated_at?: string
        }
        Update: {
          archived_at?: string | null
          created_at?: string
          created_by?: string
          default_amount?: number
          due_day?: number | null
          household_id?: string
          id?: string
          is_active?: boolean
          name?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fixed_commitment_templates_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      household_invitations: {
        Row: {
          accepted_at: string | null
          accepted_by: string | null
          created_at: string
          email: string
          expires_at: string
          household_id: string
          id: string
          invited_by: string
          status: Database["public"]["Enums"]["invitation_status"]
          token_hash: string
          updated_at: string
        }
        Insert: {
          accepted_at?: string | null
          accepted_by?: string | null
          created_at?: string
          email: string
          expires_at: string
          household_id: string
          id?: string
          invited_by: string
          status?: Database["public"]["Enums"]["invitation_status"]
          token_hash: string
          updated_at?: string
        }
        Update: {
          accepted_at?: string | null
          accepted_by?: string | null
          created_at?: string
          email?: string
          expires_at?: string
          household_id?: string
          id?: string
          invited_by?: string
          status?: Database["public"]["Enums"]["invitation_status"]
          token_hash?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "household_invitations_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      household_members: {
        Row: {
          created_at: string
          household_id: string
          id: string
          joined_at: string
          removed_at: string | null
          role: Database["public"]["Enums"]["household_role"]
          status: Database["public"]["Enums"]["member_status"]
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          household_id: string
          id?: string
          joined_at?: string
          removed_at?: string | null
          role?: Database["public"]["Enums"]["household_role"]
          status?: Database["public"]["Enums"]["member_status"]
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          household_id?: string
          id?: string
          joined_at?: string
          removed_at?: string | null
          role?: Database["public"]["Enums"]["household_role"]
          status?: Database["public"]["Enums"]["member_status"]
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "household_members_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      households: {
        Row: {
          archived_at: string | null
          created_at: string
          currency_code: string
          id: string
          name: string
          owner_user_id: string
          period_start_day: number
          timezone: string
          updated_at: string
        }
        Insert: {
          archived_at?: string | null
          created_at?: string
          currency_code?: string
          id?: string
          name: string
          owner_user_id: string
          period_start_day?: number
          timezone?: string
          updated_at?: string
        }
        Update: {
          archived_at?: string | null
          created_at?: string
          currency_code?: string
          id?: string
          name?: string
          owner_user_id?: string
          period_start_day?: number
          timezone?: string
          updated_at?: string
        }
        Relationships: []
      }
      income_sources: {
        Row: {
          archived_at: string | null
          created_at: string
          created_by: string
          default_amount: number
          household_id: string
          id: string
          is_active: boolean
          name: string
          sort_order: number
          updated_at: string
          visibility_scope: Database["public"]["Enums"]["visibility_scope"]
        }
        Insert: {
          archived_at?: string | null
          created_at?: string
          created_by: string
          default_amount?: number
          household_id: string
          id?: string
          is_active?: boolean
          name: string
          sort_order?: number
          updated_at?: string
          visibility_scope?: Database["public"]["Enums"]["visibility_scope"]
        }
        Update: {
          archived_at?: string | null
          created_at?: string
          created_by?: string
          default_amount?: number
          household_id?: string
          id?: string
          is_active?: boolean
          name?: string
          sort_order?: number
          updated_at?: string
          visibility_scope?: Database["public"]["Enums"]["visibility_scope"]
        }
        Relationships: [
          {
            foreignKeyName: "income_sources_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      monthly_items: {
        Row: {
          actual_amount: number | null
          created_at: string
          created_by: string
          due_date: string | null
          id: string
          name_snapshot: string
          period_id: string
          period_section_budget_id: string
          planned_amount: number
          recurring_template_id: string | null
          status: Database["public"]["Enums"]["monthly_item_status"]
          updated_at: string
        }
        Insert: {
          actual_amount?: number | null
          created_at?: string
          created_by: string
          due_date?: string | null
          id?: string
          name_snapshot: string
          period_id: string
          period_section_budget_id: string
          planned_amount?: number
          recurring_template_id?: string | null
          status?: Database["public"]["Enums"]["monthly_item_status"]
          updated_at?: string
        }
        Update: {
          actual_amount?: number | null
          created_at?: string
          created_by?: string
          due_date?: string | null
          id?: string
          name_snapshot?: string
          period_id?: string
          period_section_budget_id?: string
          planned_amount?: number
          recurring_template_id?: string | null
          status?: Database["public"]["Enums"]["monthly_item_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "monthly_items_period_id_fkey"
            columns: ["period_id"]
            isOneToOne: false
            referencedRelation: "budget_periods"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "monthly_items_period_section_budget_id_fkey"
            columns: ["period_section_budget_id"]
            isOneToOne: false
            referencedRelation: "period_section_budgets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "monthly_items_recurring_template_id_fkey"
            columns: ["recurring_template_id"]
            isOneToOne: false
            referencedRelation: "recurring_templates"
            referencedColumns: ["id"]
          },
        ]
      }
      period_fixed_commitments: {
        Row: {
          actual_amount: number | null
          created_at: string
          created_by: string
          due_date: string | null
          fixed_commitment_template_id: string | null
          id: string
          name_snapshot: string
          period_id: string
          planned_amount: number
          status: Database["public"]["Enums"]["monthly_item_status"]
          updated_at: string
        }
        Insert: {
          actual_amount?: number | null
          created_at?: string
          created_by: string
          due_date?: string | null
          fixed_commitment_template_id?: string | null
          id?: string
          name_snapshot: string
          period_id: string
          planned_amount?: number
          status?: Database["public"]["Enums"]["monthly_item_status"]
          updated_at?: string
        }
        Update: {
          actual_amount?: number | null
          created_at?: string
          created_by?: string
          due_date?: string | null
          fixed_commitment_template_id?: string | null
          id?: string
          name_snapshot?: string
          period_id?: string
          planned_amount?: number
          status?: Database["public"]["Enums"]["monthly_item_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "period_fixed_commitments_fixed_commitment_template_id_fkey"
            columns: ["fixed_commitment_template_id"]
            isOneToOne: false
            referencedRelation: "fixed_commitment_templates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "period_fixed_commitments_period_id_fkey"
            columns: ["period_id"]
            isOneToOne: false
            referencedRelation: "budget_periods"
            referencedColumns: ["id"]
          },
        ]
      }
      period_income_items: {
        Row: {
          actual_amount: number | null
          created_at: string
          created_by: string
          id: string
          income_source_id: string | null
          name_snapshot: string
          one_off_visibility_scope: Database["public"]["Enums"]["visibility_scope"]
          period_id: string
          planned_amount: number
          updated_at: string
        }
        Insert: {
          actual_amount?: number | null
          created_at?: string
          created_by: string
          id?: string
          income_source_id?: string | null
          name_snapshot: string
          one_off_visibility_scope?: Database["public"]["Enums"]["visibility_scope"]
          period_id: string
          planned_amount?: number
          updated_at?: string
        }
        Update: {
          actual_amount?: number | null
          created_at?: string
          created_by?: string
          id?: string
          income_source_id?: string | null
          name_snapshot?: string
          one_off_visibility_scope?: Database["public"]["Enums"]["visibility_scope"]
          period_id?: string
          planned_amount?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "period_income_items_income_source_id_fkey"
            columns: ["income_source_id"]
            isOneToOne: false
            referencedRelation: "income_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "period_income_items_period_id_fkey"
            columns: ["period_id"]
            isOneToOne: false
            referencedRelation: "budget_periods"
            referencedColumns: ["id"]
          },
        ]
      }
      period_section_budgets: {
        Row: {
          created_at: string
          id: string
          period_id: string
          planned_amount: number
          section_id: string
          section_kind_snapshot: Database["public"]["Enums"]["section_kind"]
          section_name_snapshot: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          period_id: string
          planned_amount?: number
          section_id: string
          section_kind_snapshot: Database["public"]["Enums"]["section_kind"]
          section_name_snapshot: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          period_id?: string
          planned_amount?: number
          section_id?: string
          section_kind_snapshot?: Database["public"]["Enums"]["section_kind"]
          section_name_snapshot?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "period_section_budgets_period_id_fkey"
            columns: ["period_id"]
            isOneToOne: false
            referencedRelation: "budget_periods"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "period_section_budgets_section_id_fkey"
            columns: ["section_id"]
            isOneToOne: false
            referencedRelation: "budget_sections"
            referencedColumns: ["id"]
          },
        ]
      }
      platform_admins: {
        Row: {
          created_at: string
          created_by: string | null
          is_active: boolean
          role: Database["public"]["Enums"]["platform_admin_role"]
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          is_active?: boolean
          role?: Database["public"]["Enums"]["platform_admin_role"]
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          is_active?: boolean
          role?: Database["public"]["Enums"]["platform_admin_role"]
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      profiles: {
        Row: {
          avatar_url: string | null
          created_at: string
          display_name: string | null
          id: string
          locale: string
          updated_at: string
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          display_name?: string | null
          id: string
          locale?: string
          updated_at?: string
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          display_name?: string | null
          id?: string
          locale?: string
          updated_at?: string
        }
        Relationships: []
      }
      recurring_templates: {
        Row: {
          archived_at: string | null
          created_at: string
          created_by: string
          default_amount: number
          due_day: number | null
          household_id: string
          id: string
          is_active: boolean
          name: string
          section_id: string
          updated_at: string
        }
        Insert: {
          archived_at?: string | null
          created_at?: string
          created_by: string
          default_amount?: number
          due_day?: number | null
          household_id: string
          id?: string
          is_active?: boolean
          name: string
          section_id: string
          updated_at?: string
        }
        Update: {
          archived_at?: string | null
          created_at?: string
          created_by?: string
          default_amount?: number
          due_day?: number | null
          household_id?: string
          id?: string
          is_active?: boolean
          name?: string
          section_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "recurring_templates_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recurring_templates_section_id_fkey"
            columns: ["section_id"]
            isOneToOne: false
            referencedRelation: "budget_sections"
            referencedColumns: ["id"]
          },
        ]
      }
      resource_permissions: {
        Row: {
          can_edit: boolean
          can_view: boolean
          created_at: string
          household_id: string
          id: string
          resource_id: string
          resource_type: string
          updated_at: string
          user_id: string
        }
        Insert: {
          can_edit?: boolean
          can_view?: boolean
          created_at?: string
          household_id: string
          id?: string
          resource_id: string
          resource_type: string
          updated_at?: string
          user_id: string
        }
        Update: {
          can_edit?: boolean
          can_view?: boolean
          created_at?: string
          household_id?: string
          id?: string
          resource_id?: string
          resource_type?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "resource_permissions_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      transactions: {
        Row: {
          amount: number
          created_at: string
          created_by: string
          description: string | null
          id: string
          monthly_item_id: string | null
          occurred_at: string
          period_id: string
          period_section_budget_id: string
          state: Database["public"]["Enums"]["transaction_state"]
          updated_at: string
          updated_by: string | null
          void_reason: string | null
          voided_at: string | null
          voided_by: string | null
        }
        Insert: {
          amount: number
          created_at?: string
          created_by: string
          description?: string | null
          id?: string
          monthly_item_id?: string | null
          occurred_at?: string
          period_id: string
          period_section_budget_id: string
          state?: Database["public"]["Enums"]["transaction_state"]
          updated_at?: string
          updated_by?: string | null
          void_reason?: string | null
          voided_at?: string | null
          voided_by?: string | null
        }
        Update: {
          amount?: number
          created_at?: string
          created_by?: string
          description?: string | null
          id?: string
          monthly_item_id?: string | null
          occurred_at?: string
          period_id?: string
          period_section_budget_id?: string
          state?: Database["public"]["Enums"]["transaction_state"]
          updated_at?: string
          updated_by?: string | null
          void_reason?: string | null
          voided_at?: string | null
          voided_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "transactions_monthly_item_id_fkey"
            columns: ["monthly_item_id"]
            isOneToOne: false
            referencedRelation: "monthly_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "transactions_period_id_fkey"
            columns: ["period_id"]
            isOneToOne: false
            referencedRelation: "budget_periods"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "transactions_period_section_budget_id_fkey"
            columns: ["period_section_budget_id"]
            isOneToOne: false
            referencedRelation: "period_section_budgets"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      accept_household_invitation: {
        Args: { p_token_hash: string }
        Returns: string
      }
      accept_household_invitation_by_id: {
        Args: { p_invitation_id: string }
        Returns: string
      }
      accept_household_invitation_internal: {
        Args: { p_invitation_id: string }
        Returns: string
      }
      can_contribute_to_section: {
        Args: { p_section_id: string }
        Returns: boolean
      }
      can_edit_custom_resource: {
        Args: {
          p_household_id: string
          p_resource_id: string
          p_resource_type: string
        }
        Returns: boolean
      }
      can_view_income_item: {
        Args: { p_income_item_id: string }
        Returns: boolean
      }
      can_view_resource: {
        Args: {
          p_household_id: string
          p_resource_id: string
          p_resource_type: string
          p_scope: Database["public"]["Enums"]["visibility_scope"]
        }
        Returns: boolean
      }
      can_view_section: { Args: { p_section_id: string }; Returns: boolean }
      clamped_period_start_date: {
        Args: { p_month: number; p_period_start_day: number; p_year: number }
        Returns: string
      }
      create_initial_household: {
        Args: {
          p_currency_code: string
          p_name: string
          p_period_start_day?: number
          p_timezone?: string
        }
        Returns: string
      }
      ensure_budget_period: {
        Args: { p_household_id: string }
        Returns: string
      }
      get_owner_period_planning_summary: {
        Args: { p_period_id: string }
        Returns: {
          actual_fixed_commitment_outflow: number
          actual_variable_spending_total: number
          available_after_commitments: number
          budget_remaining: number
          plan_balance: number
          planned_deficit: number
          spending_budget: number
          total_planned_commitments: number
          total_planned_income: number
          total_section_allocations: number
          unallocated_income: number
          unallocated_spending_budget: number
        }[]
      }
      is_household_member: {
        Args: { p_household_id: string }
        Returns: boolean
      }
      is_household_owner: { Args: { p_household_id: string }; Returns: boolean }
      is_period_open_for_writes: {
        Args: { p_period_id: string }
        Returns: boolean
      }
      is_platform_admin: { Args: never; Returns: boolean }
      list_my_pending_household_invitations: {
        Args: never
        Returns: {
          created_at: string
          expires_at: string
          household_id: string
          household_name: string
          invitation_id: string
          inviter_display_name: string
        }[]
      }
      mark_monthly_item_paid: {
        Args: {
          p_actual_amount?: number
          p_description?: string
          p_monthly_item_id: string
          p_occurred_at?: string
        }
        Returns: string
      }
      mark_period_fixed_commitment_paid: {
        Args: { p_actual_amount?: number; p_period_fixed_commitment_id: string }
        Returns: undefined
      }
      period_household_id: { Args: { p_period_id: string }; Returns: string }
      remove_household_member: {
        Args: { p_household_id: string; p_user_id: string }
        Returns: undefined
      }
      set_budget_period_status: {
        Args: {
          p_period_id: string
          p_reason?: string
          p_status: Database["public"]["Enums"]["period_status"]
        }
        Returns: undefined
      }
      set_monthly_item_skipped: {
        Args: { p_monthly_item_id: string; p_reason?: string; p_skip?: boolean }
        Returns: undefined
      }
      set_period_fixed_commitment_planned_amount: {
        Args: { p_period_fixed_commitment_id: string; p_planned_amount: number }
        Returns: undefined
      }
      set_period_fixed_commitment_skipped: {
        Args: {
          p_period_fixed_commitment_id: string
          p_reason?: string
          p_skip: boolean
        }
        Returns: undefined
      }
      set_period_section_allocation: {
        Args: { p_period_section_budget_id: string; p_planned_amount: number }
        Returns: undefined
      }
      set_period_spending_budget: {
        Args: { p_period_id: string; p_spending_budget: number }
        Returns: undefined
      }
      shares_household_with: {
        Args: { p_other_user_id: string }
        Returns: boolean
      }
      void_transaction: {
        Args: { p_reason?: string; p_transaction_id: string }
        Returns: undefined
      }
    }
    Enums: {
      audit_actor_type: "user" | "platform_admin" | "system"
      household_role: "owner" | "member"
      invitation_status: "pending" | "accepted" | "revoked" | "expired"
      member_status: "active" | "removed"
      monthly_item_status: "pending" | "paid" | "skipped"
      period_status: "draft" | "open" | "closed"
      platform_admin_role: "super_admin" | "support" | "read_only"
      section_kind: "fixed" | "flexible"
      section_member_access: "view" | "contribute"
      transaction_state: "posted" | "voided"
      visibility_scope: "owner_only" | "household" | "custom"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      audit_actor_type: ["user", "platform_admin", "system"],
      household_role: ["owner", "member"],
      invitation_status: ["pending", "accepted", "revoked", "expired"],
      member_status: ["active", "removed"],
      monthly_item_status: ["pending", "paid", "skipped"],
      period_status: ["draft", "open", "closed"],
      platform_admin_role: ["super_admin", "support", "read_only"],
      section_kind: ["fixed", "flexible"],
      section_member_access: ["view", "contribute"],
      transaction_state: ["posted", "voided"],
      visibility_scope: ["owner_only", "household", "custom"],
    },
  },
} as const


-- ProctorWatch 3.0 Core Schema

-- 1. Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Types/Enums
CREATE TYPE user_role AS ENUM ('student', 'teacher', 'admin', 'technical', 'parent');
CREATE TYPE test_status AS ENUM ('draft', 'scheduled', 'active', 'ended');
CREATE TYPE session_status AS ENUM ('ongoing', 'completed', 'paused', 'invalidated');
CREATE TYPE flag_severity AS ENUM ('low', 'medium', 'high');

-- 3. Tables

-- Users Table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    role user_role NOT NULL DEFAULT 'student',
    phone_number TEXT,
    avatar_url TEXT,
    first_login BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Institutions
CREATE TABLE IF NOT EXISTS institutions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Courses
CREATE TABLE IF NOT EXISTS courses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    institution_id UUID REFERENCES institutions(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL,
    teacher_id UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enrollments
CREATE TABLE IF NOT EXISTS enrollments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
    student_id UUID REFERENCES users(id) ON DELETE CASCADE,
    enrolled_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(course_id, student_id)
);

-- Tests
CREATE TABLE IF NOT EXISTS tests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    status test_status DEFAULT 'draft',
    start_time TIMESTAMP WITH TIME ZONE,
    end_time TIMESTAMP WITH TIME ZONE,
    duration_minutes INTEGER,
    total_marks INTEGER DEFAULT 100,
    passing_marks INTEGER DEFAULT 40,
    randomize_questions BOOLEAN DEFAULT true,
    negative_marking BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Questions
CREATE TABLE IF NOT EXISTS questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    text TEXT NOT NULL,
    type TEXT DEFAULT 'mcq',
    options JSONB, -- Array of strings/objects
    correct_options JSONB, -- Array of indices/values
    marks INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Test Questions (Many-to-Many)
CREATE TABLE IF NOT EXISTS test_questions (
    test_id UUID REFERENCES tests(id) ON DELETE CASCADE,
    question_id UUID REFERENCES questions(id) ON DELETE CASCADE,
    order_index INTEGER,
    PRIMARY KEY (test_id, question_id)
);

-- Exam Sessions
CREATE TABLE IF NOT EXISTS exam_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    test_id UUID REFERENCES tests(id) ON DELETE CASCADE,
    student_id UUID REFERENCES users(id) ON DELETE CASCADE,
    status session_status DEFAULT 'ongoing',
    started_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    finished_at TIMESTAMP WITH TIME ZONE,
    score DECIMAL(5,2),
    integrity_score INTEGER DEFAULT 100,
    technical_overrides JSONB DEFAULT '[]'
);

-- Answers
CREATE TABLE IF NOT EXISTS answers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES exam_sessions(id) ON DELETE CASCADE,
    question_id UUID REFERENCES questions(id),
    selected_options JSONB,
    is_correct BOOLEAN,
    marks_obtained DECIMAL(5,2),
    answered_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Flags (Violation Logs)
CREATE TABLE IF NOT EXISTS flags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES exam_sessions(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    severity flag_severity NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    evidence_url TEXT,
    details JSONB,
    status TEXT DEFAULT 'unreviewed'
);

-- Face Registrations
CREATE TABLE IF NOT EXISTS face_registrations (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    embedding FLOAT8[], -- 128-dimensional vector
    landmarks JSONB,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Audit Logs
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    action TEXT NOT NULL,
    details JSONB,
    ip_address TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Parent-Student Linking
CREATE TABLE IF NOT EXISTS parent_student (
    parent_id UUID REFERENCES users(id) ON DELETE CASCADE,
    student_id UUID REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (parent_id, student_id)
);

-- 4. Seed Data
-- Create Admin User (Using auth.uid() is typical for Supabase, but we seed the public.users)
-- NOTE: In a real Supabase environment, you would first create the user in Auth, 
-- and a trigger would insert it here. This script provides the structure.

-- Dummy Institution
INSERT INTO institutions (name, code) VALUES ('ProctorWatch Academy', 'PW001') ON CONFLICT DO NOTHING;

-- Seed Admin
-- Note: UUID is fixed for predictability in this manual setup
DO $$
DECLARE
    admin_id UUID := '00000000-0000-0000-0000-000000000000';
BEGIN
    INSERT INTO users (id, email, full_name, role, first_login)
    VALUES (admin_id, 'admin@pw.com', 'System Administrator', 'admin', true)
    ON CONFLICT (email) DO NOTHING;
END $$;

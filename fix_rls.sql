-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Patients viewable by ASHA and PHC doctors" ON patients;

-- Create new policy allowing:
-- 1. ASHA who created the patient
-- 2. Doctors in the same PHC as the patient's ASHA
-- 3. Doctors directly assigned to the patient's ASHA
-- 4. Doctors who can access triage_reports for this patient (via PHC or direct ASHA assignment)
CREATE POLICY "Patients viewable by ASHA and PHC doctors" ON patients
FOR SELECT USING (
  -- ASHA who created the patient
  auth.uid()::uuid = asha_id
  OR 
  -- Doctors in the same PHC as the patient's ASHA
  EXISTS (
    SELECT 1 FROM user_profiles up
    WHERE up.id = auth.uid()::uuid
    AND up.role = 'doctor'
    AND up.phc_id = (
      SELECT phc_id FROM user_profiles WHERE id = patients.asha_id
    )
  )
  OR
  -- Doctors directly assigned to the patient's ASHA
  EXISTS (
    SELECT 1 FROM user_profiles up
    WHERE up.id = auth.uid()::uuid
    AND up.role = 'doctor'
    AND up.id = (
      SELECT doctor_id FROM user_profiles WHERE id = patients.asha_id
    )
  )
  OR
  -- Doctors who can access triage_reports for this patient (via PHC or direct ASHA assignment)
  -- This ensures doctors who can see triage reports can also see the patient record
  EXISTS (
    SELECT 1 FROM triage_reports tr
    JOIN user_profiles asha_profile ON asha_profile.id = tr.asha_id
    WHERE tr.patient_id = patients.id
    AND (
      -- Doctor is in same PHC as the triage report's ASHA
      (EXISTS (
        SELECT 1 FROM user_profiles up
        WHERE up.id = auth.uid()::uuid
        AND up.role = 'doctor'
        AND up.phc_id = asha_profile.phc_id
      ))
      OR
      -- Doctor is directly assigned to the triage report's ASHA
      (EXISTS (
        SELECT 1 FROM user_profiles up
        WHERE up.id = auth.uid()::uuid
        AND up.role = 'doctor'
        AND up.id = asha_profile.doctor_id
      ))
    )
  )
);
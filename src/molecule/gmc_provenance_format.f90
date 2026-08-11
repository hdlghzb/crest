!================================================================================!
! Internal GMC task-final provenance transport helpers.
!================================================================================!

module gmc_provenance_format
  implicit none
  private

  character(len=*), parameter, public :: GMC_TFI_MARKER = 'GMC_TFI='
  integer, parameter, public :: GMC_TFI_TOKEN_LENGTH = 16

  public :: gmc_append_token
  public :: gmc_extract_token
  public :: gmc_make_token
  public :: gmc_token_valid

contains

  function gmc_make_token(index) result(token)
    integer, intent(in) :: index
    character(len=GMC_TFI_TOKEN_LENGTH) :: token

    if (index < 1 .or. index > 99999999) then
      error stop 'GMC task-final provenance token index is out of range.'
    end if
    write (token,'("GMC_TFI_",i8.8)') index
  end function gmc_make_token

  logical function gmc_token_valid(token)
    character(len=*), intent(in) :: token
    integer :: i

    gmc_token_valid = .false.
    if (len_trim(token) /= GMC_TFI_TOKEN_LENGTH) return
    if (token(1:8) /= 'GMC_TFI_') return
    do i = 9,GMC_TFI_TOKEN_LENGTH
      if (token(i:i) < '0' .or. token(i:i) > '9') return
    end do
    gmc_token_valid = .true.
  end function gmc_token_valid

  subroutine gmc_extract_token(comment,token,found,malformed)
    character(len=*), intent(in) :: comment
    character(len=*), intent(out) :: token
    logical, intent(out) :: found
    logical, intent(out) :: malformed
    integer :: marker_pos, start_pos, end_pos
    character :: previous

    token = ''
    found = .false.
    malformed = .false.
    marker_pos = index(comment,GMC_TFI_MARKER)
    if (marker_pos == 0) return

    if (marker_pos > 1) then
      previous = comment(marker_pos-1:marker_pos-1)
      if (previous /= ' ' .and. previous /= achar(9)) then
        malformed = .true.
        return
      end if
    end if

    start_pos = marker_pos + len(GMC_TFI_MARKER)
    end_pos = start_pos + GMC_TFI_TOKEN_LENGTH - 1
    if (end_pos > len_trim(comment)) then
      malformed = .true.
      return
    end if
    token = comment(start_pos:end_pos)
    if (.not.gmc_token_valid(token)) then
      malformed = .true.
      return
    end if
    if (end_pos < len_trim(comment)) then
      if (comment(end_pos+1:end_pos+1) /= ' ' .and. &
          comment(end_pos+1:end_pos+1) /= achar(9)) then
        malformed = .true.
        return
      end if
    end if
    found = .true.
  end subroutine gmc_extract_token

  subroutine gmc_append_token(comment,token,output)
    character(len=*), intent(in) :: comment
    character(len=*), intent(in) :: token
    character(len=*), intent(out) :: output
    character(len=256) :: marker

    if (.not.gmc_token_valid(token)) then
      error stop 'Invalid GMC task-final provenance token.'
    end if
    marker = GMC_TFI_MARKER//trim(token)
    output = trim(comment)
    if (len_trim(output) > 0) output = trim(output)//' '
    if (len_trim(output)+len_trim(marker) > len(output)) then
      error stop 'GMC task-final provenance comment is too long.'
    end if
    output = trim(output)//trim(marker)
  end subroutine gmc_append_token

end module gmc_provenance_format
